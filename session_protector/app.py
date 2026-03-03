#!/usr/bin/env python3
import os
import re
import sys
import json
import time
import queue
import signal
import subprocess
import logging
import threading
from threading import Lock, Thread
from flask import Flask, render_template, jsonify, request, Response

ANSI_RE = re.compile(r'(\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b\][^\x1b]*\x1b\\|\r)')

from monitor import ConnectionMonitor

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("session_protector.app")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ACTIONS_DIR = os.path.join(BASE_DIR, "actions")
LOG_DIR = os.path.join(BASE_DIR, "logs")
REC_DIR = os.path.join(BASE_DIR, "recordings")
ACTION_LOG = os.path.join(LOG_DIR, "actions.log")

app = Flask(__name__, template_folder="templates", static_folder="static")

connections = {}
connections_lock = Lock()
event_log = []
event_log_lock = Lock()
sse_subscribers = []
sse_lock = Lock()
active_actions = {}
active_actions_lock = Lock()
spy_watchers = {}
spy_watchers_lock = Lock()

MY_IP = os.environ.get("SP_MY_IP", "")
MY_USERNAME = os.environ.get("SP_MY_USERNAME", "")

ACTION_MAP = {
    "fake_files": "action_fake_files.sh",
    "fake_cmds": "action_fake_cmds.sh",
    "shell_chaos": "action_shell_chaos.sh",
    "keyboard": "action_keyboard.sh",
    "sounds": "action_sounds.sh",
    "messages": "action_messages.sh",
    "popups": "action_popups.sh",
    "passwords": "action_passwords.sh",
    "spy": "action_spy.sh",
    "kill": "action_kill.sh",
    "reset": "action_reset.sh",
}

ONESHOT_ACTIONS = {"kill", "reset", "passwords"}
TOGGLEABLE_ACTIONS = {"fake_files", "fake_cmds", "shell_chaos", "keyboard", "sounds", "messages", "popups", "spy"}


def load_config():
    global MY_IP, MY_USERNAME
    config_path = os.path.join(BASE_DIR, "config.env")
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    key, _, value = line.partition("=")
                    value = value.strip('"').strip("'")
                    if key == "MY_HTB_IP" and not MY_IP:
                        MY_IP = value
                    elif key == "MY_SSH_USERNAME" and not MY_USERNAME:
                        MY_USERNAME = value
    if not MY_IP or not MY_USERNAME:
        logger.error("MY_HTB_IP and MY_SSH_USERNAME must be set via env or config.env")
        sys.exit(1)
    logger.info("Config loaded: IP=%s, User=%s", MY_IP, MY_USERNAME)


def log_action(action, ip, username, result):
    os.makedirs(LOG_DIR, exist_ok=True)
    entry = "%s | %s | %s | %s | %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), action, ip, username, result)
    with open(ACTION_LOG, "a") as f:
        f.write(entry + "\n")
    return entry


def push_sse(event_type, data):
    msg = "event: %s\ndata: %s\n\n" % (event_type, json.dumps(data))
    with sse_lock:
        dead = []
        for q in sse_subscribers:
            try:
                q.put_nowait(msg)
            except queue.Full:
                dead.append(q)
        for q in dead:
            sse_subscribers.remove(q)


def action_key(ip, username, action):
    return "%s:%s:%s" % (ip, username, action)


def on_connection_event(event):
    key = "%s:%s" % (event["ip"], event["username"])
    with connections_lock:
        connections[key] = event
    with event_log_lock:
        event_log.append(event)
        if len(event_log) > 500:
            event_log.pop(0)
    push_sse("connection", event)
    logger.info("New connection event: %s", key)
    auto_spy(event["ip"], event["username"])


def on_disconnect_event(username):
    keys_to_remove = []
    with connections_lock:
        for key, conn in list(connections.items()):
            if conn["username"] == username:
                keys_to_remove.append(key)
        for key in keys_to_remove:
            connections.pop(key, None)
    for key in keys_to_remove:
        push_sse("connection_removed", {"key": key})
        logger.info("Disconnect detected: %s", key)


def auto_spy(ip, username):
    def _run():
        try:
            ak = action_key(ip, username, "spy")
            with active_actions_lock:
                if ak in active_actions:
                    return
            start_action("spy", ip, username)
        except Exception:
            logger.exception("auto_spy error")
    Thread(target=_run, daemon=True).start()


def start_action(action, ip, username):
    script_name = ACTION_MAP.get(action)
    if not script_name:
        return False, "Unknown action"
    script = os.path.join(ACTIONS_DIR, script_name)
    if not os.path.isfile(script):
        return False, "Script not found: %s" % script_name

    if action in ONESHOT_ACTIONS:
        return run_oneshot(script_name, script, action, ip, username)

    ak = action_key(ip, username, action)
    with active_actions_lock:
        if ak in active_actions:
            return False, "Already running"

    try:
        env = os.environ.copy()
        env["SP_MY_IP"] = MY_IP
        env["SP_MY_USERNAME"] = MY_USERNAME
        try:
            setsid = os.setsid
        except AttributeError:
            setsid = None
        proc = subprocess.Popen(
            ["sudo", "bash", script, ip, username, "--start"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env=env, preexec_fn=setsid,
        )
        with active_actions_lock:
            active_actions[ak] = {
                "pid": proc.pid,
                "started": time.strftime("%Y-%m-%d %H:%M:%S"),
                "action": action, "ip": ip, "username": username,
            }
        log_action(script_name, ip, username, "STARTED (pid %d)" % proc.pid)

        def wait_and_clean():
            proc.wait()
            with active_actions_lock:
                active_actions.pop(ak, None)

        Thread(target=wait_and_clean, daemon=True).start()

        push_sse("action_started", {"action": action, "ip": ip, "username": username})
        return True, "started"
    except Exception as e:
        log_action(script_name, ip, username, "ERROR: %s" % e)
        return False, str(e)


def stop_action(action, ip, username):
    script_name = ACTION_MAP.get(action)
    if not script_name:
        return False, "Unknown action"
    script = os.path.join(ACTIONS_DIR, script_name)

    ak = action_key(ip, username, action)
    with active_actions_lock:
        info = active_actions.pop(ak, None)

    if info and info.get("pid"):
        try:
            os.killpg(os.getpgid(info["pid"]), signal.SIGTERM)
        except (OSError, ProcessLookupError):
            pass

    try:
        env = os.environ.copy()
        env["SP_MY_IP"] = MY_IP
        env["SP_MY_USERNAME"] = MY_USERNAME
        result = subprocess.run(
            ["sudo", "bash", script, ip, username, "--stop"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=15, env=env,
        )
        stdout = result.stdout.decode("utf-8", errors="replace").strip() if isinstance(result.stdout, bytes) else (result.stdout or "").strip()
        stderr = result.stderr.decode("utf-8", errors="replace").strip() if isinstance(result.stderr, bytes) else (result.stderr or "").strip()
        output = stdout or stderr or "stopped"
        log_action(script_name, ip, username, "STOPPED")
        push_sse("action_stopped", {"action": action, "ip": ip, "username": username})
        return True, output
    except Exception as e:
        log_action(script_name, ip, username, "STOP_ERROR: %s" % e)
        return False, str(e)


def run_oneshot(script_name, script, action, ip, username):
    try:
        env = os.environ.copy()
        env["SP_MY_IP"] = MY_IP
        env["SP_MY_USERNAME"] = MY_USERNAME
        result = subprocess.run(
            ["sudo", "bash", script, ip, username],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=30, env=env,
        )
        stdout = result.stdout.decode("utf-8", errors="replace").strip() if isinstance(result.stdout, bytes) else (result.stdout or "").strip()
        stderr = result.stderr.decode("utf-8", errors="replace").strip() if isinstance(result.stderr, bytes) else (result.stderr or "").strip()
        output = stdout or stderr or "completed"
        success = result.returncode == 0
        log_action(script_name, ip, username, "OK" if success else "FAIL: %s" % output)
        return success, output
    except subprocess.TimeoutExpired:
        log_action(script_name, ip, username, "TIMEOUT")
        return False, "Action timed out"
    except Exception as e:
        log_action(script_name, ip, username, "ERROR: %s" % e)
        return False, str(e)


def tail_file(filepath, q, stop_event):
    try:
        with open(filepath, "r") as f:
            while not stop_event.is_set():
                line = f.readline()
                if line:
                    try:
                        q.put_nowait(line)
                    except queue.Full:
                        pass
                else:
                    time.sleep(0.3)
    except (FileNotFoundError, IOError):
        pass


@app.route("/")
def dashboard():
    return render_template("dashboard.html")


@app.route("/api/connections")
def api_connections():
    with connections_lock:
        return jsonify(list(connections.values()))


@app.route("/api/log")
def api_log():
    with event_log_lock:
        return jsonify(event_log[-100:])


@app.route("/api/active")
def api_active():
    with active_actions_lock:
        result = {}
        for ak, info in active_actions.items():
            conn_key = "%s:%s" % (info["ip"], info["username"])
            if conn_key not in result:
                result[conn_key] = []
            result[conn_key].append(info["action"])
        return jsonify(result)


@app.route("/api/action", methods=["POST"])
def api_action():
    try:
        data = request.get_json(force=True, silent=True) or {}
        ip = data.get("ip", "")
        username = data.get("username", "")
        action = data.get("action", "")
        mode = data.get("mode", "start")

        if action not in ACTION_MAP:
            return jsonify({"ok": False, "error": "Unknown action"}), 400

        if action in ONESHOT_ACTIONS:
            success, output = start_action(action, ip, username)
        elif mode == "stop":
            success, output = stop_action(action, ip, username)
        else:
            success, output = start_action(action, ip, username)

        result_data = {
            "action": action, "ip": ip, "username": username,
            "success": success, "output": output, "mode": mode,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        }
        push_sse("action_result", result_data)

        if action == "kill" and success:
            key = "%s:%s" % (ip, username)
            with connections_lock:
                connections.pop(key, None)
            push_sse("connection_removed", {"key": key})

        return jsonify({"ok": success, "output": output})
    except Exception as e:
        logger.exception("api_action error")
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/logs/download")
def api_logs_download():
    import io
    import zipfile
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for dirpath, dirnames, filenames in os.walk(REC_DIR):
            for fn in filenames:
                fp = os.path.join(dirpath, fn)
                arcname = "recordings/" + fn
                zf.write(fp, arcname)
        if os.path.isfile(ACTION_LOG):
            zf.write(ACTION_LOG, "actions.log")
    buf.seek(0)
    ts = time.strftime("%Y%m%d_%H%M%S")
    return Response(buf.getvalue(),
                    mimetype="application/zip",
                    headers={"Content-Disposition": "attachment; filename=sp_logs_%s.zip" % ts})


@app.route("/api/spy/<ip>/<username>")
def api_spy_stream(ip, username):
    cmd_log = os.path.join(REC_DIR, "%s_%s.cmds" % (username, ip))
    term_log = os.path.join(REC_DIR, "%s_%s.log" % (username, ip))

    stop = threading.Event()
    q = queue.Queue(maxsize=500)

    if os.path.isfile(cmd_log):
        t1 = Thread(target=tail_file, args=(cmd_log, q, stop), daemon=True)
        t1.start()
    if os.path.isfile(term_log):
        t2 = Thread(target=tail_file, args=(term_log, q, stop), daemon=True)
        t2.start()

    def generate():
        try:
            yield "event: spy_connected\ndata: {}\n\n"
            while True:
                try:
                    line = q.get(timeout=30)
                    clean = ANSI_RE.sub("", line)
                    if not clean.strip():
                        continue
                    payload = json.dumps({"line": clean, "ip": ip, "username": username})
                    yield "event: spy_data\ndata: %s\n\n" % payload
                except queue.Empty:
                    yield ": keepalive\n\n"
        except GeneratorExit:
            pass
        finally:
            stop.set()

    return Response(generate(), mimetype="text/event-stream",
                    headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


@app.route("/api/stream")
def api_stream():
    q = queue.Queue(maxsize=100)
    with sse_lock:
        sse_subscribers.append(q)

    def generate():
        try:
            yield "event: connected\ndata: {}\n\n"
            while True:
                try:
                    msg = q.get(timeout=30)
                    yield msg
                except queue.Empty:
                    yield ": keepalive\n\n"
        except GeneratorExit:
            pass
        finally:
            with sse_lock:
                if q in sse_subscribers:
                    sse_subscribers.remove(q)

    return Response(generate(), mimetype="text/event-stream",
                    headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


if __name__ == "__main__":
    load_config()
    os.makedirs(LOG_DIR, exist_ok=True)
    os.makedirs(REC_DIR, exist_ok=True)
    monitor = ConnectionMonitor(MY_IP, MY_USERNAME, on_connection_event, on_disconnect_event)
    monitor.start()
    logger.info("Starting SessionProtector dashboard on http://0.0.0.0:5000")
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)
