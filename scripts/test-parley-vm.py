#!/usr/bin/env python3
"""One owned Tart clone; prepare exits 75 while live acceptance is pending."""
import argparse
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

IMAGE = 'ghcr.io/cirruslabs/macos-tahoe-base@sha256:1b093499716409d29e8b5336844528e1cae375db97d2ad8e5aeff78cf0da201e'
REPO = Path(__file__).resolve().parent.parent
TART = os.environ.get('TART', 'tart')
ENV = dict(os.environ, TART_NO_AUTO_PRUNE='1')


def command(args, timeout=900, check=True):
    # Capture guest output: provider URLs and credentials must never reach reports.
    result = subprocess.run([TART] + args, env=ENV, capture_output=True, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError('Tart command failed: ' + args[0])
    return result


def guest(vm, script, timeout=900):
    return command(['exec', vm, '/bin/zsh', '-lc', 'set -eu; ' + script], timeout)


def save(directory, manifest):
    temporary = directory / 'manifest.tmp'
    temporary.write_text(json.dumps(manifest, indent=2) + '\n')
    temporary.replace(directory / 'manifest.json')


def cleanup(directory, manifest, lock):
    # Stop/delete only the clone named by both our reservation and manifest.
    command(['stop', manifest['vm']], 30, check=False)
    command(['delete', manifest['vm']], 60)
    manifest['status'] = 'cleaned'
    save(directory, manifest)
    lock.unlink()


def install(directory, manifest):
    vm = manifest['vm']
    manifest['phase'] = 'install'
    save(directory, manifest)
    guest(vm, 'brew install xianxu/parley/parley', 900)
    manifest['phase'] = 'boot'
    save(directory, manifest)
    probe = base64.b64encode((REPO / 'tests/packaging/vm_acceptance.lua').read_bytes()).decode()
    guest(vm, 'umask 077; mkdir -p "$HOME/.parley-acceptance" "$HOME/.config/nvim"; '
          'test ! -e "$HOME/.config/nvim/init.lua"; '
          'printf \'error("decoy nvim config was sourced")\\n\' > "$HOME/.config/nvim/init.lua"; '
          'shasum -a 256 "$HOME/.config/nvim/init.lua" > "$HOME/.parley-acceptance/decoy.sha"; '
          "printf '%s' '" + probe + "' | base64 -D > \"$HOME/.parley-acceptance/probe.lua\"; "
          'parley --headless -n -i NONE -c \'lua if not pcall(dofile, vim.env.HOME .. "/.parley-acceptance/probe.lua") then vim.cmd("cquit 1") end\' -c qa', 900)
    evidence = json.loads(guest(vm, 'cat "$HOME/.parley-acceptance/boot.json"', 30).stdout)
    if not all(evidence.get(key) is True for key in ('boot', 'containment', 'decoy_unchanged')):
        raise RuntimeError('incomplete boot evidence')
    manifest['install'] = dict(evidence, status='passed')
    manifest['status'] = 'auth_pending'
    save(directory, manifest)
    print('PENDING: guest authentication and live acceptance; owned VM:', vm)
    print('Manifest:', directory / 'manifest.json')
    return 75


def probe_phase(directory, manifest, phase):
    vm = manifest['vm']
    manifest['phase'] = phase
    save(directory, manifest)
    for source, name in [('tests/packaging/vm_chat.lua', 'vm_chat.lua'),
                         ('tests/packaging/vm_chat_probe.lua', 'vm_chat_probe.lua'),
                         ('tests/fixtures/one_pixel.png', 'one_pixel.png')]:
        encoded = base64.b64encode((REPO / source).read_bytes()).decode()
        guest(vm, 'umask 077; mkdir -p "$HOME/.parley-acceptance"; '
              + "printf '%s' '" + encoded + "' | base64 -D > "
              + '\"$HOME/.parley-acceptance/' + name + '\"')
    script = ('PARLEY_VM_PHASE=' + phase + ' parley --headless -n -i NONE '
              + '-c \'lua dofile(vim.env.HOME .. "/.parley-acceptance/vm_chat_probe.lua")\' '
              + '>/dev/null 2>&1; result=$?; '
              + 'cat "$HOME/.parley-acceptance/phase.json"; exit "$result"')
    result = command(['exec', vm, '/bin/zsh', '-lc', script], 900, check=False)
    evidence = json.loads(result.stdout)
    if result.returncode == 75 and evidence.get('status') == 'auth_pending':
        manifest['status'] = 'auth_pending'
        save(directory, manifest)
        print('PENDING: open parley in the guest and use :ParleyConnect to complete OAuth')
        return 75
    if result.returncode != 0 or evidence.get('status') == 'failed':
        raise RuntimeError('guest phase failed')
    if phase == 'fake' and not all(evidence.get(field) is True for field in
                                   ('fake', 'first_use', 'managed_route', 'response_nonempty')):
        raise RuntimeError('incomplete fake evidence')
    key = 'live' if phase == 'check-live' else phase
    if phase == 'check-live':
        if not all(evidence.get(field) is True for field in
                   ('response_nonempty', 'image_sent', 'managed_route')):
            raise RuntimeError('incomplete live evidence')
        if evidence.get('status') != 'live_verified':
            raise RuntimeError('invalid live outcome')
    manifest[key] = evidence
    save(directory, manifest)
    print('VERIFIED guest phase:', phase)
    return 0


def upload(vm, source, destination):
    encoded = base64.b64encode((REPO / source).read_bytes()).decode()
    guest(vm, 'umask 077; mkdir -p "$HOME/.parley-acceptance"; '
          + "printf '%s' '" + encoded + "' | base64 -D > "
          + '"$HOME/.parley-acceptance/' + destination + '"')


def package_phase(directory, manifest, phase):
    vm = manifest['vm']
    manifest['phase'] = phase
    save(directory, manifest)
    if phase == 'upgrade':
        upload(vm, 'scripts/test-parley-upgrade.sh', 'upgrade.sh')
        guest(vm, 'sh "$HOME/.parley-acceptance/upgrade.sh" '
              + '"$(brew --prefix parley)/libexec" "$HOME/.parley-acceptance/upgrade"', 900)
        result = guest(vm, 'cat "$HOME/.parley-acceptance/upgrade/upgrade.json"', 30)
    else:
        upload(vm, 'tests/packaging/vm_stop.lua', 'vm_stop.lua')
        upload(vm, 'tests/packaging/vm_uninstall.py', 'vm_uninstall.py')
        guest(vm, 'parley --headless -n -i NONE -c '
              + '\'lua if not pcall(dofile, vim.env.HOME .. "/.parley-acceptance/vm_stop.lua") then vim.cmd("cquit 1") end\' '
              + '-c qa!', 60)
        guest(vm, 'python3 "$HOME/.parley-acceptance/vm_uninstall.py"', 900)
        result = guest(vm, 'cat "$HOME/.parley-acceptance/uninstall.json"', 30)
    evidence = json.loads(result.stdout)
    candidate = dict(manifest, **{phase: evidence})
    if phase in missing_evidence(candidate):
        raise RuntimeError('incomplete package phase evidence')
    manifest[phase] = evidence
    if phase == 'upgrade':
        # Live acceptance must run against the restored public package.
        manifest.pop('live', None)
    save(directory, manifest)
    print('VERIFIED guest phase:', phase)
    return 0


def missing_evidence(manifest):
    required = {
        'install': ('boot', 'containment', 'decoy_unchanged'),
        'fake': ('fake', 'first_use', 'managed_route', 'response_nonempty'),
        'live': ('managed_route', 'response_nonempty', 'image_sent'),
        'upgrade': ('decoy_unchanged', 'public_restored'),
        'uninstall': ('package_removed', 'owned_proxy_absent', 'decoy_unchanged'),
    }
    missing = []
    for phase, fields in required.items():
        record = manifest.get(phase, {})
        if not all(record.get(field) is True for field in fields):
            missing.append(phase)
            continue
        if phase == 'live' and record.get('status') != 'live_verified':
            missing.append(phase)
        elif phase in ('install', 'upgrade', 'uninstall') and record.get('status') != 'passed':
            missing.append(phase)
        elif phase == 'upgrade' and (record.get('versions') != ['0.0.1', '0.0.2']
                or any(len(record.get(key, '')) != 64 for key in ('edited_init_sha256', 'candidate_b_sha256'))):
            missing.append(phase)
        elif phase == 'uninstall' and record.get('profile_roots_removed') != ['cache', 'config', 'data', 'state']:
            missing.append(phase)
    return missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['boot', 'prepare', 'install', 'fake', 'prepare-auth', 'check-live', 'upgrade', 'uninstall', 'verify', 'cleanup'])
    parser.add_argument('directory', type=Path, help='private run directory containing ownership manifest')
    args = parser.parse_args()
    directory = args.directory.resolve()
    lock = Path.home() / '.cache/parley-vm-acceptance.owner'
    if args.phase not in ('prepare', 'boot'):
        manifest = json.loads((directory / 'manifest.json').read_text())
        reservation = json.loads(lock.read_text())
        if reservation != {'vm': manifest['vm'], 'directory': str(directory)}:
            raise RuntimeError('ownership reservation does not match manifest')
        if not manifest['vm'].startswith('parley-acceptance-'):
            raise RuntimeError('invalid owned VM name')
        if args.phase == 'cleanup':
            cleanup(directory, manifest, lock)
            print('CLEANED owned VM')
            return 0
        if args.phase == 'install':
            if manifest['status'] != 'boot_ready':
                raise RuntimeError('install requires a boot_ready owned run')
            try:
                return install(directory, manifest)
            except BaseException:
                manifest['outcome'] = 'failed'
                cleanup(directory, manifest, lock)
                raise
        if args.phase in ('fake', 'prepare-auth', 'check-live'):
            if manifest['status'] == 'boot_ready':
                raise RuntimeError('install before running guest probes')
            if args.phase == 'check-live' and not manifest.get('fake', {}).get('first_use'):
                raise RuntimeError('run fake before live acceptance')
            try:
                return probe_phase(directory, manifest, args.phase)
            except BaseException:
                manifest['outcome'] = 'failed'
                cleanup(directory, manifest, lock)
                raise
        if args.phase in ('upgrade', 'uninstall'):
            if not manifest.get('install'):
                raise RuntimeError('install before package acceptance')
            if args.phase == 'uninstall' and any(phase != 'uninstall' for phase in missing_evidence(manifest)):
                print('PENDING: complete install, fake, upgrade, and live phases before uninstall')
                return 75
            try:
                return package_phase(directory, manifest, args.phase)
            except BaseException:
                manifest['outcome'] = 'failed'
                cleanup(directory, manifest, lock)
                raise
        missing = missing_evidence(manifest)
        if missing:
            print('PENDING acceptance evidence:', ', '.join(missing))
            return 75
        cleanup(directory, manifest, lock)
        manifest['outcome'] = 'complete'
        save(directory, manifest)
        print('COMPLETE: all acceptance phases verified and owned VM removed')
        return 0
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    if (directory / 'manifest.json').exists():
        raise RuntimeError('existing run: resume verify or cleanup')
    lock.parent.mkdir(parents=True, exist_ok=True)
    vm = 'parley-acceptance-' + uuid.uuid4().hex
    reservation = {'vm': vm, 'directory': str(directory)}
    with lock.open('x') as handle:
        json.dump(reservation, handle)
    manifest = {'schema': 1, 'vm': vm, 'image': IMAGE, 'status': 'preflight'}
    clone_attempted = False
    try:
        disk = Path(os.environ.get('TART_HOME', str(Path.home() / '.tart')))
        while not disk.exists():
            disk = disk.parent
        free = shutil.disk_usage(disk).free
        if free < 60 * 1024 ** 3:
            raise RuntimeError('at least 60 GiB free disk required')
        manifest['free_before_bytes'] = free
        save(directory, manifest)
        command(['list', '--format', 'json'], 30)
        clone_attempted = True
        manifest['phase'] = 'clone'
        save(directory, manifest)
        command(['clone', IMAGE, vm])
        manifest['free_after_clone_bytes'] = shutil.disk_usage(disk).free
        manifest['observed_clone_allocation_bytes'] = free - manifest['free_after_clone_bytes']
        print('Observed clone allocation bytes:', manifest['observed_clone_allocation_bytes'])
        subprocess.Popen([TART, 'run', '--no-graphics', '--no-audio', '--no-clipboard', vm],
                         env=ENV, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        manifest['phase'] = 'readiness'
        save(directory, manifest)
        deadline = time.monotonic() + 180
        while True:
            try:
                guest(vm, 'command -v brew >/dev/null && brew --version >/dev/null',
                      timeout=max(1, min(10, deadline - time.monotonic())))
                break
            except (RuntimeError, subprocess.TimeoutExpired):
                if time.monotonic() >= deadline:
                    raise RuntimeError('guest agent/Homebrew readiness exceeded 180 seconds')
                time.sleep(1)
        if args.phase == 'boot':
            manifest['status'] = 'boot_ready'
            save(directory, manifest)
            print('BOOT READY owned VM:', vm)
            print('Manifest:', directory / 'manifest.json')
            return 0
        return install(directory, manifest)
    except BaseException:
        manifest['outcome'] = 'failed'
        manifest['status'] = 'failed'
        save(directory, manifest)
        if clone_attempted:
            cleanup(directory, manifest, lock)
        else:
            lock.unlink()
        raise


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        # Only controlled failure kinds, never captured command output.
        print('VM acceptance failed:', type(error).__name__, file=sys.stderr)
        sys.exit(1)
