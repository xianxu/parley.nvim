#!/usr/bin/env python3
"""Run a real fixture with hostile reverse DNS and publish its listening port."""
import os
import runpy
import socket
import socketserver
import sys
import time

sys.dont_write_bytecode = True
ready, mode, fixture = sys.argv[1:4]
sys.argv = sys.argv[3:]
sys.path.insert(0, os.path.dirname(os.path.abspath(fixture)))


def unavailable(*_args):
    if mode == 'hang':
        time.sleep(30)
    raise AssertionError('reverse DNS must not run in loopback fixtures')


socket.getfqdn = unavailable
socket.gethostbyaddr = unavailable
activate = socketserver.TCPServer.server_activate


def announce(server):
    activate(server)
    with open(ready + '.partial', 'w') as handle:
        handle.write(str(server.server_address[1]))
    os.replace(ready + '.partial', ready)


socketserver.TCPServer.server_activate = announce
runpy.run_path(fixture, run_name='__main__')
