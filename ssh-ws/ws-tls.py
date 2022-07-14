import logging
import socket
import ssl
import sys
from logging import DEBUG, INFO
from socketserver import StreamRequestHandler, ThreadingTCPServer
from urllib.request import urlopen, Request

from select import select as ss

DEFAULT_HOST = b'127.0.0.1:143'
SSH_PORT = 143
DEFAULT_RESPONSE = b''

logging.basicConfig(level=0)

try:
    with urlopen(Request("https://aarestu.github.io")) as response:
        DEFAULT_RESPONSE = response.read()
except:
    print("err init DEFAULT_RESPONSE")


class Server(ThreadingTCPServer):
    allow_reuse_address = True
    timeout = 60

    def __init__(self, server_address, RequestHandlerClass, certfile, keyfile, ssl_version=ssl.PROTOCOL_TLSv1_2,
                 bind_and_activate=True):
        super(Server, self).__init__(server_address, RequestHandlerClass, bind_and_activate)

        self.certfile = certfile
        self.keyfile = keyfile
        self.ssl_version = ssl_version

    def get_request(self):
        newsocket, fromaddr = self.socket.accept()
        connstream = ssl.wrap_socket(newsocket, server_side=True, certfile=self.certfile, keyfile=self.keyfile,
                                     ssl_version=self.ssl_version)
        return connstream, fromaddr


class Handler(StreamRequestHandler):
    buffer_size = 2 ** 13

    logger = logging.getLogger()

    def handle(self):
        data = self.connection.recv(self.buffer_size)
        print(data)
        accept = self.findHeader(data, b'accept')
        if b"html" in accept:
            self.connection.send(b'HTTP/1.1 200 OK\n\n' + DEFAULT_RESPONSE)
            return

        self.do_connect(DEFAULT_HOST)

    def do_connect(self, host_port):
        host = host_port.split(b":")[0].decode()

        self.connection.send(b'HTTP/1.1 101 Switching Protocols\r\n\r\n')

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as ssh:
            if self.server.timeout:
                ssh.settimeout(self.server.timeout)
            try:
                ssh.connect((host, SSH_PORT))
                self.forward_data(ssh, self.connection)
            except Exception as e:
                self.log(DEBUG, e)
                pass

    def forward_data(self, remote, client):
        self.log(INFO, "forward data connection")
        try:
            while True:
                sockets = [remote, client]

                r, _, _ = ss(sockets, [], [])

                if client in r:
                    data = client.recv(self.buffer_size)
                    # self.log(INFO, b"fc:" + data)
                    if remote.send(data) <= 0:
                        break

                if remote in r:
                    data = remote.recv(self.buffer_size)
                    # self.log(INFO, b"fs:" + data)
                    if client.send(data) <= 0:
                        break
        except ConnectionError as e:
            self.log(DEBUG, e)

    def log(self, level, msg):
        self.logger.log(level, msg)

    def findHeader(self, head, header):
        aux = head.find(header + b': ')

        if aux == -1:
            return b''

        aux = head.find(b':', aux)
        head = head[aux + 2:]
        aux = head.find(b'\r\n')

        if aux == -1:
            return b''

        return head[:aux]


if __name__ == '__main__':
    LISTENING_PORT = int(sys.argv[1])

    with Server(("", LISTENING_PORT), Handler, "/etc/ssl/cert.pem", "/etc/ssl/key.pem") as httpd:
        print("serving at port", LISTENING_PORT)
        httpd.serve_forever()
