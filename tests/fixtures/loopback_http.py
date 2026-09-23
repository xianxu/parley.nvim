"""HTTP fixtures bind numeric loopback addresses without consulting reverse DNS.

Binding a port is the moment a fixture becomes long-lived, and every fixture server
in this tree binds through this class — so this is also where they are given their
end (#220, ARCH-FUNERAL). A fixture reparented to init outlives its spec forever:
#220 measured 897 of them holding ~10 GB. Opting in per fixture is what left
fake_sse_server, and six of fake_cliproxy's eight spawn sites, uncovered.

This covers the SERVER shape only. A fixture that blocks without binding — the
`hangs` login in fake_cliproxy, `slow` mode in fake_sips — calls exit_with_parent
itself; tests/arch/fixture_lifecycle_spec.lua enforces that every fixture reaches
it one way or the other.
"""
import os
import sys
from http.server import HTTPServer
from socketserver import TCPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fixture_watchdog import exit_with_parent  # noqa: E402


class LoopbackHTTPServer(HTTPServer):
    def __init__(self, *args, **kwargs):
        exit_with_parent()
        HTTPServer.__init__(self, *args, **kwargs)

    def server_bind(self):
        # HTTPServer.server_bind calls getfqdn(), which can block in the guest's
        # mDNS resolver before listen(). These fixtures need only literal identity.
        TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]
