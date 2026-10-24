#!/usr/bin/env python3
"""Stateful pair#777 operator protocol fake, invoked only by fake_couch.

FAKE_COUCH_OPERATOR_TRACE: JSONL requests, including failed requests.
FAKE_COUCH_OPERATOR_CODE / _EXIT: refusal before effects (default exit by code).
FAKE_COUCH_OPERATOR_ACK: raw reply replacing a successful acknowledgment.
FAKE_COUCH_OPERATOR_ACQUIRE_WRITE: replace document bytes before acquire ack.
FAKE_COUCH_OPERATOR_DELAY: seconds after effects, before replying; SIGTERM kills
this process directly, so no child retains the response pipes.
FAKE_COUCH_OPERATOR_PRE_DELAY: seconds before effects, a call killed at its
budget before it changed anything (#432). Knobs except
TRACE apply only to acquire by default; _OPS is a comma-list of verbs to target.
Registry fixtures validate registration identity under the registry flock;
standalone native fixtures adopt the supplied ID for an existing document.
Synthetic fixture IDs are accepted; real producer IDs are 32 lowercase hex.
"""
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import re
import sys
import time


def refusal(code, error, exit_code=1):
    return exit_code, dict(Code=code, Error=error)


def lock_fields(text):
    """Match the producer's known-field grammar; unrelated lines are ignored."""
    if len(text) > 4096 or '\0' in text:
        return None
    fields = {}
    for line in text.splitlines():
        key, separator, value = line.partition(':')
        if separator and key in ('holder', 'time', 'document', 'turn'):
            if key in fields:
                return None
            fields[key] = value.strip()
    return fields


def ownership(text, identity, turn):
    fields = lock_fields(text)
    if fields is None:
        return False
    try:
        datetime.fromisoformat(fields.get('time', '').replace('Z', '+00:00'))
    except ValueError:
        return False
    return (fields.get('holder') == 'operator' and fields.get('document') == identity
            and fields.get('turn') == turn)


def operate(args):
    if (len(args) != 8 or args[0] != '--session-sync' or args[1] not in
            ('operator-acquire', 'operator-release') or args[3] != '--id'
            or args[5] != '--turn' or args[7] != '--json'):
        return refusal('usage', 'expected FILE --id ID --turn TOKEN --json', 2)
    _, op, filename, _, identity, _, turn, _ = args
    if not identity or '\n' in identity or not re.fullmatch('[0-9a-f]{32}', turn):
        return refusal('operator-invalid', 'invalid document identity or turn')
    path = Path(filename).resolve()
    lock_path = Path(str(path) + '.lock')
    registry = os.environ.get('FAKE_COUCH_REGISTRY')
    transaction = Path(registry + '.lock') if registry else Path(str(path) + '.operator-transaction')
    try:
        with transaction.open('a') as guard:
            fcntl.flock(guard, fcntl.LOCK_EX)
            if registry:
                state_path = Path(registry)
                state = json.loads(state_path.read_text()) if state_path.exists() else {}
                registration = state.get('paths', {}).get(str(path))
                if not registration:
                    return refusal('not-registered', 'canonical path is not registered')
                if registration.get('ID') != identity:
                    return refusal('document-mismatch', 'registration identity mismatch')
            if not path.is_file():
                return refusal('not-registered', 'document is absent')
            targeted = op in os.environ.get('FAKE_COUCH_OPERATOR_OPS', 'operator-acquire').split(',')
            if targeted:
                time.sleep(float(os.environ.get('FAKE_COUCH_OPERATOR_PRE_DELAY', '0')))
            injection = os.environ.get('FAKE_COUCH_OPERATOR_CODE') if targeted else None
            if injection:
                default = 7 if injection == 'session-sync-unavailable' else 3 if injection == 'operator-lock' else 1
                return refusal(injection, 'injected operator protocol failure',
                               int(os.environ.get('FAKE_COUCH_OPERATOR_EXIT', str(default))))
            text = lock_path.read_text() if lock_path.exists() else None
            # A well-formed legacy agent sidecar is free, not operator ownership.
            fields = lock_fields(text) if text is not None else None
            agent = fields is not None and fields.get('holder') == 'agent'
            if agent:
                text = None
            if text is not None and not ownership(text, identity, turn):
                return refusal('operator-lock', 'foreign, stale, or legacy protection', 3)
            if op == 'operator-acquire':
                state = 'already-held' if text is not None else 'acquired'
                if text is None:
                    text = ('holder: operator\ntime: ' + datetime.now(timezone.utc).isoformat()
                            + '\ndocument: ' + identity + '\nturn: ' + turn + '\n')
                    lock_path.write_text(text)
                replacement = os.environ.get('FAKE_COUCH_OPERATOR_ACQUIRE_WRITE')
                if replacement is not None:
                    path.write_text(replacement)
            else:
                state = 'released' if text is not None else 'already-released'
                if text is not None:
                    lock_path.unlink()
            envelope = dict(Code='ok', Error='', OperatorLock=dict(
                ID=identity, File=str(path), Holder='operator' if op == 'operator-acquire' else '', Turn=turn,
                LockPath=str(lock_path), LockText=(text or '') if op == 'operator-acquire' else '', State=state))
        if targeted:
            time.sleep(float(os.environ.get('FAKE_COUCH_OPERATOR_DELAY', '0')))
            if 'FAKE_COUCH_OPERATOR_ACK' in os.environ:
                return 0, os.environ['FAKE_COUCH_OPERATOR_ACK']
        return 0, envelope
    except (OSError, ValueError) as error:
        return refusal('session-sync-unavailable', str(error), 7)


def main():
    args = sys.argv[1:]
    trace = os.environ.get('FAKE_COUCH_OPERATOR_TRACE')
    if trace:
        with open(trace, 'a') as output:
            output.write(json.dumps(dict(argv=args, op=args[1] if len(args) > 1 else '')) + '\n')
    code, reply = operate(args)
    print(reply if isinstance(reply, str) else json.dumps(reply), flush=True)
    return code


if __name__ == '__main__':
    sys.exit(main())
