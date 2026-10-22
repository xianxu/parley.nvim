"""Bounded, asynchronous consumer of the couch-conformance-bridge protocol.

The producer owns its artifacts and their teardown. This module owns only the
process groups it starts; it never deletes or launches producer-owned resources.
"""
import asyncio
import json
import os
from pathlib import Path
import re
import signal
import subprocess


class _Tail:
    def __init__(self, limit):
        self.limit = limit
        self.data = b''
        self.truncated = False

    def add(self, data):
        self.truncated |= len(self.data) + len(data) > self.limit
        self.data = (self.data + data)[-self.limit:]

    def text(self):
        return ('[diagnostics truncated]\n' if self.truncated else '') + self.data.decode('utf-8', 'replace')


def _readiness(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError('duplicate JSON key: ' + key)
            result[key] = value
        return result

    def absolute(value):
        return isinstance(value, str) and bool(value) and '\0' not in value and os.path.isabs(value)

    value = json.loads(raw, object_pairs_hook=pairs)
    if not isinstance(value, dict) or type(value.get('Version')) is not int or value['Version'] != 1:
        raise ValueError('unsupported readiness version')
    namespace = value.get('Namespace')
    if not absolute(namespace) or os.path.realpath(namespace) != namespace:
        raise ValueError('Namespace must be an absolute physical path')
    if not absolute(value.get('Socket')):
        raise ValueError('Socket must be absolute')
    env = value.get('Environment')
    if not isinstance(env, dict) or not all(isinstance(k, str) and bool(k) and isinstance(v, str) and '\0' not in k + v and '=' not in k for k, v in env.items()):
        raise ValueError('Environment must be a string map')
    if not env.get('PATH'):
        raise ValueError('Environment must supply private PATH')
    docs = value.get('Documents')
    if not isinstance(docs, list) or len(docs) != 2:
        raise ValueError('Documents must contain ordered parent and child')
    ids = []
    for doc in docs:
        if not isinstance(doc, dict) or not isinstance(doc.get('ID'), str) or not re.fullmatch('[0-9a-f]{32}', doc['ID']) or not absolute(doc.get('File')):
            raise ValueError('invalid document')
        ids.append(doc['ID'])
    if ids[0] == ids[1]:
        raise ValueError('duplicate document ID')
    parent, child = (Path(doc['File']) for doc in docs)
    if parent.suffix != '.md' or child.suffix != '.md' or child.parent != parent.parent / (parent.stem + '.side'):
        raise ValueError('invalid parent/child document paths')
    return value


def _signal_group(process, sig):
    # A reaped leader's numeric PGID is no longer proof of ownership.
    if process.returncode is not None:
        return False
    try:
        os.killpg(process.pid, sig)
        return True
    except ProcessLookupError:
        return False


async def _drain(stream, tail):
    while data := await stream.read(8192):
        tail.add(data)


async def _complete(coroutine):
    """Delay cancellation until owned teardown has joined every reader/process."""
    task = asyncio.create_task(coroutine)
    cancelled = False
    while True:
        try:
            result = await asyncio.shield(task)
            break
        except asyncio.CancelledError:
            if task.cancelled():
                raise
            cancelled = True
    if cancelled:
        raise asyncio.CancelledError
    return result


class BridgeSession:
    """Own a bridge group and bounded native probes under one lifetime budget."""
    def __init__(self, argv, env, startup_s=300, lifetime_s=600, stop_s=15, margin_s=15):
        self.argv = list(argv)
        self.env = dict(env)
        self.startup_s = startup_s
        self.lifetime_s = lifetime_s
        self.stop_s = stop_s
        self.margin_s = margin_s
        self.readiness = None
        self.cleaned = False
        self._tail = _Tail(65536)
        self._process = None
        self._failure = None
        self._probe_task = None
        self._watchdog = None
        self._closed = False

    @property
    def diagnostics(self):
        suffix = ''
        if not self.cleaned:
            root = self.readiness['Namespace'] if self.readiness else '(readiness unavailable; see producer diagnostics)'
            suffix = '\nProducer cleanup unconfirmed; retained-root: ' + root
        return self._tail.text() + suffix

    def _fail(self, message):
        if self._failure is None:
            self._failure = message

    async def _stdout(self):
        pending = bytearray()
        complete = False
        while chunk := await self._process.stdout.read(8192):
            if complete:
                self._fail('bridge emitted more than one readiness record')
                continue
            pending.extend(chunk)
            newline = pending.find(b'\n')
            if len(pending) > 65536 and (newline < 0 or newline + 1 > 65536):
                self._fail('readiness exceeds 65536 bytes')
                complete = True
            elif newline >= 0:
                complete = True
                try:
                    self.readiness = _readiness(bytes(pending[:newline]))
                except (ValueError, UnicodeError) as error:
                    self._fail('invalid readiness: ' + str(error))
                if len(pending) != newline + 1:
                    self._fail('bridge emitted extra stdout')
            if complete:
                pending.clear()
                self._ready.set()
        if not complete:
            self._fail('bridge EOF before complete readiness')
            self._ready.set()

    async def _joined(self):
        await self._process.wait()
        await asyncio.gather(*self._readers)

    async def _expire(self):
        await asyncio.sleep(max(0, self._active_deadline - asyncio.get_running_loop().time()))
        self._fail('bridge lifetime deadline exceeded; cleanup unknown')
        if self._probe_task:
            self._probe_task.cancel()
            await asyncio.gather(self._probe_task, return_exceptions=True)
        if not _signal_group(self._process, signal.SIGTERM):
            return
        await asyncio.sleep(self.stop_s)
        _signal_group(self._process, signal.SIGKILL)

    async def __aenter__(self):
        loop = asyncio.get_running_loop()
        self._entered = loop.time()
        self._active_deadline = self._entered + self.lifetime_s
        self._overall_deadline = self._active_deadline + self.stop_s + self.margin_s
        self._ready = asyncio.Event()
        try:
            self._process = await asyncio.wait_for(asyncio.create_subprocess_exec(
                *self.argv, env=self.env, stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
                start_new_session=True), timeout=min(self.startup_s, self.lifetime_s))
            self._readers = [asyncio.create_task(self._stdout()), asyncio.create_task(_drain(self._process.stderr, self._tail))]
            self._join = asyncio.create_task(self._joined())
            self._watchdog = asyncio.create_task(self._expire())
            startup_remaining = min(self._entered + self.startup_s, self._active_deadline) - loop.time()
            await asyncio.wait_for(self._ready.wait(), max(0, startup_remaining))
            if self._failure:
                raise RuntimeError(self._failure)
            return self
        except BaseException as error:
            self._fail('bridge startup failed: ' + str(error))
            await _complete(self._finish())
            if isinstance(error, asyncio.CancelledError):
                raise
            raise RuntimeError(self._failure + '\n' + self.diagnostics) from error

    async def run(self, argv, *, env, cwd=None, timeout=30):
        """Run one owned probe with a full replacement environment; join on cancel."""
        if self._closed or self._failure:
            raise RuntimeError(self._failure or 'bridge session is closed')
        if self._probe_task:
            raise RuntimeError('only one probe may run at a time')
        task = asyncio.create_task(self._run_owned(argv, env=env, cwd=cwd, timeout=timeout))
        self._probe_task = task
        try:
            return await asyncio.shield(task)
        except asyncio.CancelledError:
            task.cancel()
            await _complete(self._join_probe(task))
            raise
        finally:
            self._probe_task = None

    async def _join_probe(self, task):
        await asyncio.gather(task, return_exceptions=True)

    async def _hard_join(self, process, joined, readers, deadline):
        """After KILL, bound observation even if a foreign descendant holds a pipe."""
        if not _signal_group(process, signal.SIGKILL) and not joined.done():
            self._fail('leader exited with inherited pipes still open; cleanup unknown')
        try:
            remaining = max(0, deadline - asyncio.get_running_loop().time())
            await asyncio.wait_for(asyncio.shield(joined), remaining)
        except TimeoutError:
            self._fail('owned process pipe join deadline exceeded; cleanup unknown')
            # StreamReader exposes no public close operation. Close only our
            # subprocess transports, then join the cancelled drain tasks.
            process._transport.close()
            for reader in readers:
                reader.cancel()
            joined.cancel()
            await asyncio.gather(joined, *readers, return_exceptions=True)
            await process.wait()

    async def _run_owned(self, argv, *, env, cwd, timeout):
        process = None
        readers = []
        joined = None
        out, err = _Tail(1048576), _Tail(1048576)
        try:
            remaining = self._active_deadline - asyncio.get_running_loop().time()
            async with asyncio.timeout(min(timeout, max(0, remaining))):
                process = await asyncio.create_subprocess_exec(*list(argv), env=dict(env), cwd=cwd,
                    stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE, start_new_session=True)
                process.stdin.close()
                readers = [asyncio.create_task(_drain(process.stdout, out)), asyncio.create_task(_drain(process.stderr, err))]
                async def join():
                    await process.wait()
                    await asyncio.gather(*readers)
                joined = asyncio.create_task(join())
                await asyncio.shield(joined)
            return subprocess.CompletedProcess(list(argv), process.returncode, out.text(), err.text())
        except (asyncio.CancelledError, TimeoutError):
            if asyncio.get_running_loop().time() >= self._active_deadline:
                self._fail('bridge lifetime deadline exceeded; cleanup unknown')
                raise RuntimeError(self._failure)
            raise
        finally:
            if process:
                if not joined or not joined.done():
                    if not _signal_group(process, signal.SIGTERM):
                        self._fail('leader exited with inherited pipes still open; cleanup unknown')
                if joined:
                    try:
                        await asyncio.wait_for(asyncio.shield(joined), min(.2, self.margin_s))
                    except TimeoutError:
                        deadline = min(self._overall_deadline, asyncio.get_running_loop().time() + self.margin_s)
                        await self._hard_join(process, joined, readers, deadline)

    async def _finish(self):
        if self._closed:
            return
        self._closed = True
        if not self._process:
            return
        if self._probe_task and self._probe_task is not asyncio.current_task():
            self._probe_task.cancel()
            await asyncio.gather(self._probe_task, return_exceptions=True)
        if self._watchdog:
            self._watchdog.cancel()
            await asyncio.gather(self._watchdog, return_exceptions=True)
        self._process.stdin.close()
        remaining = self._overall_deadline - asyncio.get_running_loop().time()
        try:
            await asyncio.wait_for(asyncio.shield(self._join), max(0, min(self.stop_s, remaining)))
        except TimeoutError:
            self._fail('bridge EOF stop deadline exceeded; producer cleanup unknown')
            _signal_group(self._process, signal.SIGTERM)
            remaining = self._overall_deadline - asyncio.get_running_loop().time()
            try:
                await asyncio.wait_for(asyncio.shield(self._join), max(0, min(self.margin_s / 2, remaining)))
            except TimeoutError:
                deadline = min(self._overall_deadline, asyncio.get_running_loop().time() + self.margin_s / 2)
                await self._hard_join(self._process, self._join, self._readers, deadline)
        if self._process.returncode != 0:
            self._fail('bridge exited nonzero: ' + str(self._process.returncode))
        self.cleaned = self._failure is None and self.readiness is not None

    async def __aexit__(self, exc_type, exc, tb):
        await _complete(self._finish())
        if self._failure:
            raise RuntimeError(self._failure + '\n' + self.diagnostics) from exc
        return False
