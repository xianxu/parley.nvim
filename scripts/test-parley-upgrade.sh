#!/bin/sh
# Disposable macOS guest only: temporarily substitutes a local fixture for public parley.
set -eu
exec python3 - "$@" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile

if len(sys.argv) != 3:
    sys.exit('usage: test-parley-upgrade.sh INSTALLED_RUNTIME ACCEPTANCE_WORKDIR')
runtime = Path(sys.argv[1]).resolve(strict=True)
work = Path(sys.argv[2]).resolve()
work.mkdir(parents=True, exist_ok=True)
report = work / 'upgrade.json'
if report.exists() or report.is_symlink():
    sys.exit('upgrade report already exists; use a fresh acceptance work directory')
owned = work / 'upgrade-fixture'
owned.mkdir()  # Never adopt or delete an existing run's directory.
tap_name = 'parley-acceptance/fixtures'
formula_name = tap_name + '/parley-upgrade-fixture'
env = dict(os.environ, HOMEBREW_NO_AUTO_UPDATE='1')

def run(*argv, extra=None):
    result = subprocess.run(argv, env=dict(env, **(extra or {})), text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=900)
    if result.returncode:
        raise RuntimeError(f'{argv[0]} {argv[1]} failed ({result.returncode}): {result.stderr.strip()}')
    return result.stdout.strip()

def snapshot(path):
    if not path.exists():
        return {}
    return {str(item.relative_to(path)): ('link:' + os.readlink(item) if item.is_symlink()
            else hashlib.sha256(item.read_bytes()).hexdigest())
            for item in sorted(path.rglob('*')) if item.is_file() or item.is_symlink()}

config = Path(env.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))
initial = config / 'parley/init.lua'
original = None
tap_created = unlinked = fixture_attempted = False
success = None
failure = None
cleanup_errors = []
try:
    if initial.is_symlink() or not initial.is_file():
        raise RuntimeError('public Parley must already have a regular profile init.lua')
    original = initial.read_bytes()
    edited = original + b'\n-- acceptance: preserve this edited profile through brew upgrade\n'
    decoy = snapshot(config / 'nvim')
    tap_path = Path(run('brew', '--repository', tap_name))
    if tap_path.exists():
        raise RuntimeError('acceptance fixture tap already exists; refusing to adopt it')
    run('brew', 'tap-new', tap_name)
    tap_created = True
    formula_path = tap_path / 'Formula/parley-upgrade-fixture.rb'
    source = owned / 'runtime'
    shutil.copytree(runtime, source, symlinks=True, ignore=shutil.ignore_patterns('.git'))
    starter = source / 'packaging/starter-config/init.lua'
    # Homebrew moves this file from libexec into share during formula install.
    # Reconstruct the release source from that same installed prefix, not another version.
    starter_original = (runtime.parent / 'share/parley/config/init.lua').read_bytes()
    starter.parent.mkdir(parents=True, exist_ok=True)
    launcher = Path(run('brew', '--prefix')) / 'bin/parley'
    initial.write_bytes(edited)
    run('brew', 'unlink', 'parley')
    unlinked = True
    for version, marker, operation in [('0.0.1', 'A', 'install'), ('0.0.2', 'B', 'upgrade')]:
        expected = starter_original + f'\n-- acceptance fixture {marker}\n'.encode()
        starter.write_bytes(expected)
        archive = owned / f'parley-upgrade-fixture-{version}.tar.gz'
        with tarfile.open(archive, 'w:gz') as output:
            for child in sorted(source.iterdir()):
                output.add(child, arcname=child.name)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        rendered = owned / 'rendered.rb'
        run('nvim', '--headless', '-n', '--noplugin', '-u', 'NONE', '-i', 'NONE',
            '-l', str(source / 'packaging/render-formula.lua'),
            extra={'PARLEY_RELEASE_TAG': 'v' + version, 'PARLEY_RELEASE_SHA256': digest,
                   'PARLEY_RELEASE_OUTPUT': str(rendered)})
        formula = rendered.read_text().replace('class Parley < Formula', 'class ParleyUpgradeFixture < Formula')
        formula, count = re.subn(r'^  url "[^"]+"$', '  url "' + archive.as_uri() + '"', formula, flags=re.M)
        if count != 1:
            raise RuntimeError('release renderer did not produce exactly one archive URL')
        formula_path.write_text(formula)
        fixture_attempted = True
        run('brew', operation, formula_name)
        if 'NVIM' not in run(str(launcher), '--version'):
            raise RuntimeError('fixture launcher did not reach Neovim')
        if initial.read_bytes() != edited:
            raise RuntimeError('upgrade overwrote the edited profile')
        if (initial.parent / 'init.lua.new').read_bytes() != expected:
            raise RuntimeError('upgrade candidate differs from the complete packaged starter')
        if snapshot(config / 'nvim') != decoy:
            raise RuntimeError('upgrade changed the separate nvim profile')
    success = {'status': 'passed', 'versions': ['0.0.1', '0.0.2'],
               'edited_init_sha256': hashlib.sha256(edited).hexdigest(),
               'candidate_b_sha256': hashlib.sha256(expected).hexdigest(), 'decoy_unchanged': True}
except Exception as error:
    failure = error
finally:
    # Try every restoration even if an earlier cleanup command fails.
    actions = []
    if fixture_attempted:
        actions.append(('brew', 'uninstall', formula_name))
    if tap_created:
        actions.append(('brew', 'untap', tap_name))
    if unlinked:
        actions.append(('brew', 'link', 'parley'))
    for argv in actions:
        try:
            run(*argv)
        except Exception as error:
            cleanup_errors.append(str(error))
    if original is not None:
        try:
            initial.write_bytes(original)
        except Exception as error:
            cleanup_errors.append(str(error))
    if unlinked and not cleanup_errors:
        try:
            if 'NVIM' not in run(str(launcher), '--version'):
                raise RuntimeError('restored public launcher did not reach Neovim')
        except Exception as error:
            cleanup_errors.append(str(error))
    shutil.rmtree(owned)
if failure or cleanup_errors:
    sys.exit('upgrade acceptance failed: ' + '; '.join([str(failure)] if failure else [])
             + ('; cleanup: ' + '; '.join(cleanup_errors) if cleanup_errors else ''))
success['public_restored'] = True
report.write_text(json.dumps(success, indent=2) + '\n')
print(report)
PY
