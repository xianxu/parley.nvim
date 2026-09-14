"""HTTP fixtures bind numeric loopback addresses without consulting reverse DNS."""
from http.server import HTTPServer
from socketserver import TCPServer


class LoopbackHTTPServer(HTTPServer):
    def server_bind(self):
        # HTTPServer.server_bind calls getfqdn(), which can block in the guest's
        # mDNS resolver before listen(). These fixtures need only literal identity.
        TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]
