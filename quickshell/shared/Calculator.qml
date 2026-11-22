pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Calculator: qalc evaluation for CalculatorPopup, shared by every screen's popup.
// Talks to one long-running quickshell/scripts/calc.py (JSON lines; started on
// the first request, stopped after `idleTimeout` without requests, restarted on
// demand). Only the newest request is answered; older replies are dropped.
//   Calculator.evaluate("5 ft to m")  →  result "1.524 m", latex, image (PNG preview)
// result / latex / image / expression belong to the last expression that
// evaluated; while the current input has an `error` they keep showing that last
// good evaluation (the popup mutes it) instead of blanking on every keystroke.
Singleton {
	id: root

	property string expression: "" // input that produced result / latex / image
	property string result: ""
	property string latex: ""      // "expression = result" (mathtext-compatible LaTeX)
	property string image: ""      // file:// URL of the rendered LaTeX, or ""
	property real imageScale: 1    // image pixels per screen pixel
	property string error: ""      // the current input does not evaluate
	property string warning: ""    // first qalc warning of the current input
	readonly property bool busy: d.answeredId !== d.lastId
	// Session history, newest first: [{ expression, result, latex }].
	property var history: []
	readonly property int maxHistory: 8
	readonly property int idleTimeout: 300000

	// The newest request was answered (or failed).
	signal answered()

	// Start the helper ahead of the first request (its first preview needs ~0.5 s
	// of matplotlib warm-up).
	function start() {
		idleTimer.restart();
		helper.running = true;
	}

	function evaluate(input) {
		const expr = input.trim();
		d.lastId++;
		if (expr === "") {
			d.answeredId = d.lastId;
			expression = "";
			result = "";
			latex = "";
			image = "";
			error = "";
			warning = "";
			return;
		}
		d.pendingExpression = expr;
		d.retried = false;
		d.send(JSON.stringify({ id: d.lastId, expr: expr, color: d.hex(Theme.foreground) }) + "\n");
	}

	function copy(text) {
		if (text !== "")
			Quickshell.execDetached(["wl-copy", "--", text]);
	}

	// Push the current evaluation onto the history (moving a repeat to the top).
	function remember() {
		if (expression === "" || result === "")
			return;
		const entry = { expression: expression, result: result, latex: latex };
		history = [entry].concat(history.filter(h => h.expression !== expression)).slice(0, maxHistory);
	}

	function handleReply(line) {
		let r;
		try {
			r = JSON.parse(line);
		} catch (e) {
			return;
		}
		if (r.id !== d.lastId)
			return;
		d.answeredId = r.id;
		error = r.error ?? "";
		warning = r.warnings && r.warnings.length > 0 ? r.warnings[0] : "";
		if (error === "") {
			expression = d.pendingExpression;
			result = r.result ?? "";
			latex = r.latex ?? "";
			image = r.image ? "file://" + r.image : "";
			imageScale = r.scale || 1;
		}
		answered();
	}

	QtObject {
		id: d
		property int lastId: 0
		property int answeredId: 0
		property string pendingExpression: ""
		property string lastRequest: ""
		property bool started: false
		property bool retried: false

		function send(request) {
			lastRequest = request;
			idleTimer.restart();
			if (started)
				helper.write(request);
			else
				helper.running = true; // onStarted sends lastRequest
		}

		// "#rrggbb" (Qt's color string is #aarrggbb when not opaque).
		function hex(c) {
			const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
			return "#" + h(c.r) + h(c.g) + h(c.b);
		}
	}

	Process {
		id: helper
		command: ["python3", Quickshell.shellPath("scripts/calc.py")]
		stdinEnabled: true
		stdout: SplitParser {
			onRead: line => root.handleReply(line)
		}
		onStarted: {
			d.started = true;
			if (root.busy)
				helper.write(d.lastRequest);
		}
		onExited: {
			d.started = false;
			if (!root.busy)
				return;
			if (!d.retried) {
				// Died mid-request: restart once (onStarted resends the request).
				d.retried = true;
				Qt.callLater(() => helper.running = true);
			} else {
				d.answeredId = d.lastId;
				root.error = "Calculator backend (python3 calc.py) failed";
				root.answered();
			}
		}
	}

	Timer {
		id: idleTimer
		interval: root.idleTimeout
		onTriggered: {
			if (!root.busy)
				helper.running = false;
		}
	}
}
