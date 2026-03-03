var attackerList = document.getElementById("attacker-list");
var noConnections = document.getElementById("no-connections");
var connCount = document.getElementById("conn-count");
var eventLog = document.getElementById("event-log");
var statusEl = document.getElementById("status");
var noSelection = document.getElementById("no-selection");
var detailPanel = document.getElementById("attacker-detail");
var detailHeader = document.getElementById("detail-header");
var actionsGrid = document.getElementById("actions-grid");
var spyOutput = document.getElementById("spy-output");
var spyStatus = document.getElementById("spy-status");
var cmdLogOutput = document.getElementById("cmd-log-output");

var activeConnections = {};
var activeActions = {};
var selectedAttacker = null;

var spySources = {};
var spyBuffers = {};
var cmdBuffers = {};

var ONESHOT = { kill: true, reset: true, passwords: true };

function init() {
  fetch("/api/connections")
    .then(function (r) { return r.json(); })
    .then(function (conns) {
      conns.forEach(function (c) { addConnection(c); });
    });

  fetch("/api/log")
    .then(function (r) { return r.json(); })
    .then(function (entries) {
      entries.forEach(function (e) { appendLog(e); });
    });

  fetch("/api/active")
    .then(function (r) { return r.json(); })
    .then(function (data) {
      Object.keys(data).forEach(function (connKey) {
        if (!activeActions[connKey]) activeActions[connKey] = {};
        data[connKey].forEach(function (action) {
          activeActions[connKey][action] = true;
        });
      });
      renderSidebar();
      if (selectedAttacker) renderDetail();
    });

  connectSSE();
}

function connectSSE() {
  var es = new EventSource("/api/stream");

  es.addEventListener("connected", function () {
    statusEl.className = "status connected";
    statusEl.innerHTML = '<span class="dot"></span> Monitoring';
  });

  es.addEventListener("connection", function (e) {
    var data = JSON.parse(e.data);
    addConnection(data);
    appendLog(data);
    toast("New: " + data.username + "@" + data.ip, "info");
  });

  es.addEventListener("action_result", function (e) {
    var data = JSON.parse(e.data);
    appendActionResult(data);
    var label = data.action.toUpperCase();
    var status = data.success ? "OK" : "FAILED";
    toast(label + " " + data.username + "@" + data.ip + ": " + status,
      data.success ? "success" : "error");
  });

  es.addEventListener("action_started", function (e) {
    var data = JSON.parse(e.data);
    var key = data.ip + ":" + data.username;
    if (!activeActions[key]) activeActions[key] = {};
    activeActions[key][data.action] = true;
    renderSidebar();
    if (selectedAttacker === key) renderDetail();
  });

  es.addEventListener("action_stopped", function (e) {
    var data = JSON.parse(e.data);
    var key = data.ip + ":" + data.username;
    if (activeActions[key]) {
      delete activeActions[key][data.action];
    }
    renderSidebar();
    if (selectedAttacker === key) renderDetail();
  });

  es.addEventListener("connection_removed", function (e) {
    var data = JSON.parse(e.data);
    removeConnection(data.key);
  });

  es.onerror = function () {
    statusEl.className = "status";
    statusEl.innerHTML = '<span class="dot"></span> Reconnecting...';
  };
}

function addConnection(conn) {
  var key = conn.ip + ":" + conn.username;
  if (activeConnections[key]) return;
  activeConnections[key] = conn;
  if (!activeActions[key]) activeActions[key] = {};
  startSpyStream(key, conn);
  renderSidebar();
}

function removeConnection(key) {
  stopSpyStream(key);
  delete activeConnections[key];
  if (selectedAttacker === key) {
    selectedAttacker = null;
    renderDetail();
  }
  renderSidebar();
}

function startSpyStream(key, conn) {
  if (spySources[key]) return;

  if (!spyBuffers[key]) spyBuffers[key] = [];
  if (!cmdBuffers[key]) cmdBuffers[key] = [];

  var src = new EventSource("/api/spy/" + encodeURIComponent(conn.ip) + "/" + encodeURIComponent(conn.username));

  src.addEventListener("spy_data", function (e) {
    var data = JSON.parse(e.data);
    var line = data.line;

    spyBuffers[key].push(line);

    if (line.match(/^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]/)) {
      cmdBuffers[key].push(line.trim());
    }

    if (selectedAttacker === key) {
      spyOutput.textContent += line;
      spyOutput.scrollTop = spyOutput.scrollHeight;

      if (line.match(/^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]/)) {
        var div = document.createElement("div");
        div.className = "cmd-entry";
        div.innerHTML = '<span class="cmd-text">' + esc(line.trim()) + '</span>';
        cmdLogOutput.appendChild(div);
        cmdLogOutput.scrollTop = cmdLogOutput.scrollHeight;
      }
    }
  });

  spySources[key] = src;
}

function stopSpyStream(key) {
  if (spySources[key]) {
    spySources[key].close();
    delete spySources[key];
  }
}

function selectAttacker(key) {
  selectedAttacker = key;
  renderSidebar();
  renderDetail();
  showBufferedSpy(key);
}

function showBufferedSpy(key) {
  spyOutput.textContent = "";
  cmdLogOutput.innerHTML = "";

  var termLines = spyBuffers[key] || [];
  spyOutput.textContent = termLines.join("");
  spyOutput.scrollTop = spyOutput.scrollHeight;

  var cmds = cmdBuffers[key] || [];
  for (var i = 0; i < cmds.length; i++) {
    var div = document.createElement("div");
    div.className = "cmd-entry";
    div.innerHTML = '<span class="cmd-text">' + esc(cmds[i]) + '</span>';
    cmdLogOutput.appendChild(div);
  }
  cmdLogOutput.scrollTop = cmdLogOutput.scrollHeight;
}

function renderSidebar() {
  var keys = Object.keys(activeConnections);
  connCount.textContent = keys.length;
  noConnections.style.display = keys.length ? "none" : "flex";

  var items = keys.map(function (key) {
    var conn = activeConnections[key];
    var isSelected = selectedAttacker === key;
    var actions = activeActions[key] || {};
    var cmdCount = (cmdBuffers[key] || []).length;
    var badges = Object.keys(actions).map(function (a) {
      return '<span class="action-badge active">' + esc(a) + '</span>';
    }).join("");

    return '<div class="attacker-item' + (isSelected ? " selected" : "") +
      '" onclick="selectAttacker(\'' + escAttr(key) + '\')">' +
      '<span class="attacker-user">' + esc(conn.username) + '</span>' +
      '<span class="attacker-ip">' + esc(conn.ip) + '</span>' +
      '<span class="attacker-time">' + esc(conn.timestamp) +
      (cmdCount > 0 ? ' &middot; ' + cmdCount + ' cmds' : '') + '</span>' +
      (badges ? '<div class="attacker-badges">' + badges + '</div>' : "") +
      '</div>';
  });

  var listEl = document.getElementById("attacker-list");
  var noConn = noConnections.outerHTML;
  listEl.innerHTML = (keys.length ? "" : noConn) + items.join("");
}

function renderDetail() {
  if (!selectedAttacker || !activeConnections[selectedAttacker]) {
    noSelection.style.display = "flex";
    detailPanel.style.display = "none";
    return;
  }

  noSelection.style.display = "none";
  detailPanel.style.display = "flex";

  var conn = activeConnections[selectedAttacker];
  detailHeader.innerHTML = '<span class="detail-user">' + esc(conn.username) +
    '</span> @ <span class="detail-ip">' + esc(conn.ip) +
    '</span> <span style="color:var(--text-dim);font-size:12px;margin-left:12px">' +
    esc(conn.timestamp) + '</span>';

  var actions = activeActions[selectedAttacker] || {};
  var btns = actionsGrid.querySelectorAll(".action-btn");
  for (var i = 0; i < btns.length; i++) {
    var action = btns[i].getAttribute("data-action");
    if (actions[action]) {
      btns[i].classList.add("active");
    } else {
      btns[i].classList.remove("active");
    }
  }

  var isSpying = !!actions["spy"];
  spyStatus.textContent = isSpying ? "Recording" : "Stopped";
  spyStatus.style.background = isSpying ? "var(--green)" : "var(--red)";
}

function doAction(action) {
  if (!selectedAttacker) return;
  var conn = activeConnections[selectedAttacker];
  if (!conn) return;

  var actions = activeActions[selectedAttacker] || {};
  var isActive = !!actions[action];
  var mode = (ONESHOT[action] || !isActive) ? "start" : "stop";

  var btn = actionsGrid.querySelector('[data-action="' + action + '"]');
  if (btn) btn.disabled = true;

  fetch("/api/action", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      ip: conn.ip,
      username: conn.username,
      action: action,
      mode: mode,
    }),
  })
    .then(function (r) { return r.json(); })
    .then(function (data) {
      if (!data.ok) toast("Failed: " + data.output, "error");
    })
    .catch(function (err) { toast("Request failed: " + err, "error"); })
    .finally(function () { if (btn) btn.disabled = false; });
}

(function () {
  var grid = document.getElementById("actions-grid");
  grid.addEventListener("click", function (e) {
    var btn = e.target.closest(".action-btn");
    if (!btn || btn.disabled) return;
    doAction(btn.getAttribute("data-action"));
  });
})();

function appendLog(entry) {
  var div = document.createElement("div");
  div.className = "log-entry";
  div.innerHTML = '<span class="ts">' + esc(entry.timestamp) + '</span> ' +
    '<span class="ip">' + esc(entry.ip) + '</span> ' +
    '<span class="user">' + esc(entry.username) + '</span>';
  eventLog.appendChild(div);
  eventLog.scrollTop = eventLog.scrollHeight;
}

function appendActionResult(data) {
  var div = document.createElement("div");
  div.className = "log-entry action-result" + (data.success ? "" : " failed");
  div.innerHTML = '<span class="ts">' + esc(data.timestamp) + '</span> ' +
    '[' + esc(data.action.toUpperCase()) + '] ' +
    esc(data.ip) + ' ' + esc(data.username) + ' - ' +
    (data.success ? "OK" : "FAILED: " + esc(data.output));
  eventLog.appendChild(div);
  eventLog.scrollTop = eventLog.scrollHeight;
}

function clearLog() {
  eventLog.innerHTML = "";
}

function toggleEventBar() {
  document.getElementById("event-bar").classList.toggle("collapsed");
}

function toast(msg, type) {
  var container = document.getElementById("toast-container");
  var el = document.createElement("div");
  el.className = "toast " + type;
  el.textContent = msg;
  container.appendChild(el);
  setTimeout(function () { el.remove(); }, 4000);
}

function esc(s) {
  if (!s) return "";
  var d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

function escAttr(s) {
  return s.replace(/'/g, "\\'").replace(/"/g, "&quot;");
}

init();
