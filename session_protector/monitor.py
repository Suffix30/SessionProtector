import os
import re
import time
import subprocess
import threading
import logging

logger = logging.getLogger("session_protector.monitor")

AUTH_LOG = "/var/log/auth.log"

SSH_PATTERNS = [
    re.compile(r"Accepted password for (\S+) from (\d+\.\d+\.\d+\.\d+)"),
    re.compile(r"Accepted publickey for (\S+) from (\d+\.\d+\.\d+\.\d+)"),
    re.compile(r"Accepted keyboard-interactive/pam for (\S+) from (\d+\.\d+\.\d+\.\d+)"),
]


class ConnectionMonitor:
    def __init__(self, my_ip, my_username, connect_cb, disconnect_cb=None):
        self.my_ip = my_ip
        self.my_username = my_username
        self.connect_cb = connect_cb
        self.disconnect_cb = disconnect_cb
        self._stop = threading.Event()
        self._thread = None
        self._checker = None
        self._known_users = set()

    def start(self):
        self._thread = threading.Thread(target=self._tail_log, daemon=True)
        self._thread.start()
        if self.disconnect_cb:
            self._checker = threading.Thread(target=self._check_loop, daemon=True)
            self._checker.start()
        logger.info("Monitor started, tailing %s", AUTH_LOG)

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=3)

    def _tail_log(self):
        while not self._stop.is_set():
            try:
                self._follow_log()
            except FileNotFoundError:
                logger.warning("%s not found, retrying in 5s", AUTH_LOG)
                time.sleep(5)
            except Exception:
                logger.exception("Monitor error, restarting in 2s")
                time.sleep(2)

    def _follow_log(self):
        with open(AUTH_LOG, "r") as f:
            f.seek(0, os.SEEK_END)
            while not self._stop.is_set():
                line = f.readline()
                if not line:
                    time.sleep(0.5)
                    continue
                self._parse_line(line.strip())

    def _parse_line(self, line):
        for pattern in SSH_PATTERNS:
            match = pattern.search(line)
            if match:
                username, ip = match.groups()
                if ip == self.my_ip and username == self.my_username:
                    logger.debug("Own connection from %s@%s, ignoring", username, ip)
                    return
                self._known_users.add(username)
                event = {
                    "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "ip": ip,
                    "username": username,
                    "raw": line,
                }
                logger.info("Detected connection: %s@%s", username, ip)
                self.connect_cb(event)
                return

    def _check_loop(self):
        while not self._stop.is_set():
            time.sleep(10)
            try:
                self._check_disconnects()
            except Exception:
                logger.exception("Disconnect check error")

    def _check_disconnects(self):
        try:
            proc = subprocess.Popen(
                ["who"], stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            out, _ = proc.communicate(timeout=5)
            output = out.decode("utf-8", errors="replace") if isinstance(out, bytes) else (out or "")
        except Exception:
            return

        logged_in = set()
        for line in output.strip().split("\n"):
            if line.strip():
                parts = line.split()
                if parts:
                    logged_in.add(parts[0])

        gone = set()
        for user in list(self._known_users):
            if user == self.my_username:
                continue
            if user not in logged_in:
                gone.add(user)
                self._known_users.discard(user)

        for user in gone:
            logger.info("Detected disconnect: %s", user)
            if self.disconnect_cb:
                self.disconnect_cb(user)
