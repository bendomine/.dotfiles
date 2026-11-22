import Quickshell
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Calculator popup on the launcher pill (quickshell:toggle-calculator, Super+R,
// or the launcher's Calculator tile):
//   CalculatorPopup { anchorItem: launcherPill }
// Type a qalc expression ("2^10 + sqrt(16)", "5 ft to m", "solve(x^2 = 4)"); the
// result and a rendered LaTeX preview update live (Calculator singleton +
// scripts/calc.py). The input keeps keyboard focus, so every printable key
// (h/j/k/l, Space…) types; popup navigation only gets the keys it leaves:
//   Return              copy the result (wl-copy), add it to the history
//   Shift+Return        copy the LaTeX instead
//   Down / Up           move into / within the history (Up past the top: back to input)
//   Return on a row     put its expression back into the input
//   Shift+Return / right click on a row   copy its result
//   Escape              close
BarPopup {
	id: popup
	shortcutName: "toggle-calculator"
	hoverToOpen: false
	clickToToggle: false
	contentWidth: 380

	// Input changed and its evaluation is not in yet.
	readonly property bool stale: debounce.running || Calculator.busy

	function copyResult(kind) {
		if (input.text.trim() === "")
			return;
		if (debounce.running) {
			debounce.stop();
			Calculator.evaluate(input.text);
		}
		if (Calculator.busy)
			d.copyPending = kind; // finished in onAnswered
		else
			copyCurrent(kind);
	}

	function copyCurrent(kind) {
		d.copyPending = "";
		if (Calculator.error !== "" || Calculator.result === "")
			return;
		const text = kind === "latex" ? Calculator.latex : Calculator.result;
		if (text === "")
			return;
		Calculator.copy(text);
		Calculator.remember();
		showCopied(kind);
		input.selectAll(); // typing replaces it
	}

	function showCopied(kind) {
		d.copied = kind;
		copiedTimer.restart();
	}

	function reinsert(expression) {
		input.text = expression;
		input.cursorPosition = input.text.length;
		input.forceActiveFocus();
		setFocusItem(null);
	}

	QtObject {
		id: d
		property string copyPending: "" // "result" | "latex": copy once the reply is in
		property string copied: ""      // "result" | "latex" while the feedback shows
	}

	Timer {
		id: debounce
		interval: 80
		onTriggered: Calculator.evaluate(input.text)
	}

	Timer {
		id: copiedTimer
		interval: 1400
		onTriggered: d.copied = ""
	}

	Connections {
		target: Calculator
		function onAnswered() {
			if (d.copyPending !== "" && popup.open)
				popup.copyCurrent(d.copyPending);
		}
	}

	onOpenChanged: {
		if (!open) {
			d.copyPending = "";
			return;
		}
		// Calculator state is shared with the other screens' popups: re-evaluate ours
		// (also picks up a theme change for the preview colour).
		Calculator.start();
		debounce.stop();
		Calculator.evaluate(input.text);
		Qt.callLater(() => {
			input.forceActiveFocus();
			input.selectAll();
		});
	}

	PopupHeader {
		icon: "󰃬"
		title: "Calculator"
		subtitle: "Enter copies · Shift+Enter copies LaTeX"

		KeyHint {
			label: d.copied === "latex" ? "LaTeX copied" : "Copied"
			tint: Theme.success
			opacity: d.copied !== "" ? 1 : 0
			Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
		}
	}

	// ── Input ────────────────────────────────────────────────────────────
	Rectangle {
		Layout.fillWidth: true
		implicitHeight: 40
		radius: Theme.radiusSmall
		color: Theme.surfaceVariant
		border.width: input.activeFocus ? 2 : 1
		border.color: input.activeFocus ? Theme.accent : Theme.alpha(Theme.border, 0.9)
		Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

		RowLayout {
			anchors.fill: parent
			anchors.leftMargin: Theme.spacing
			anchors.rightMargin: Theme.spacing
			spacing: Theme.spacing

			Glyph {
				text: "󰃬"
				font.pixelSize: Theme.fontSizeLarge
				color: input.activeFocus ? Theme.accent : Theme.foregroundMuted
			}

			Item {
				Layout.fillWidth: true
				Layout.fillHeight: true

				TextInput {
					id: input
					anchors.fill: parent
					// Active focus whenever the popup's key scope has it (BarPopup
					// focuses that scope on open), so typed keys reach the input first.
					focus: true
					verticalAlignment: TextInput.AlignVCenter
					clip: true
					font.family: Theme.fontFamily
					font.pixelSize: Theme.fontSizeLarge
					color: Theme.foreground
					selectionColor: Theme.accent
					selectedTextColor: Theme.onAccent
					selectByMouse: true

					onTextChanged: {
						popup.setFocusItem(null); // typing leaves the history
						if (text.trim() === "") {
							debounce.stop();
							Calculator.evaluate("");
						} else {
							debounce.restart();
						}
					}

					Keys.onPressed: event => {
						const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
						switch (event.key) {
						case Qt.Key_Return:
						case Qt.Key_Enter: {
							const row = popup.focusItem;
							if (row && !row.mouseFocused) {
								// A history row picked with Up/Down.
								if (shift)
									row.activateAlt();
								else
									row.activate();
							} else {
								popup.copyResult(shift ? "latex" : "result");
							}
							break;
						}
						case Qt.Key_Down: {
							const rows = popup.navItems();
							if (popup.focusIdx < rows.length - 1)
								popup.moveFocus(1);
							break;
						}
						case Qt.Key_Up:
							if (popup.focusIdx <= 0)
								popup.setFocusItem(null);
							else
								popup.moveFocus(-1);
							break;
						default:
							return;
						}
						event.accepted = true;
					}
				}

				StyledText {
					anchors.fill: parent
					visible: input.text === ""
					text: "2^10 + sqrt(16), 5 ft to m, …"
					font.pixelSize: Theme.fontSizeLarge
					color: Theme.foregroundMuted
					elide: Text.ElideRight
				}
			}
		}
	}

	// ── Result ───────────────────────────────────────────────────────────
	// While the input does not evaluate (error, or still typing) the last good
	// result and preview stay, muted, with the reason below.
	RowLayout {
		Layout.fillWidth: true
		Layout.topMargin: Theme.spacingSmall
		Layout.leftMargin: Theme.spacingSmall
		Layout.rightMargin: Theme.spacingSmall
		visible: input.text.trim() !== "" && Calculator.result !== ""
		spacing: Theme.spacing

		StyledText {
			Layout.alignment: Qt.AlignTop
			text: "="
			font.pixelSize: 24
			color: Theme.foregroundMuted
		}
		StyledText {
			Layout.fillWidth: true
			text: Calculator.result
			font.pixelSize: 24
			font.weight: Font.Bold
			color: Calculator.error !== "" ? Theme.foregroundMuted : Theme.accent
			wrapMode: Text.WrapAnywhere
			maximumLineCount: 3
			elide: Text.ElideRight
		}
	}

	StyledText {
		Layout.fillWidth: true
		Layout.leftMargin: Theme.spacingSmall
		Layout.rightMargin: Theme.spacingSmall
		visible: text !== ""
		text: {
			if (input.text.trim() === "")
				return "qalc syntax: units, constants, functions, “to” conversions";
			if (Calculator.error !== "")
				return Calculator.error;
			return Calculator.warning;
		}
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.foregroundMuted
		wrapMode: Text.Wrap
		maximumLineCount: 2
		elide: Text.ElideRight
	}

	// LaTeX preview: rendered at `imageScale` × screen pixels, shown at 1×
	// (shrunk further to fit the popup).
	Item {
		Layout.fillWidth: true
		Layout.topMargin: Theme.spacingSmall
		visible: input.text.trim() !== "" && Calculator.image !== "" && preview.status === Image.Ready
		implicitHeight: preview.height + 2 * Theme.spacing

		Rectangle {
			anchors.fill: parent
			radius: Theme.radiusSmall
			color: Theme.alpha(Theme.foreground, 0.04)
		}

		Image {
			id: preview
			readonly property real naturalWidth: implicitWidth / Calculator.imageScale
			readonly property real maxWidth: parent.width - 2 * Theme.spacing
			anchors.centerIn: parent
			width: Math.min(naturalWidth, maxWidth)
			height: implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
			source: Calculator.image
			cache: false
			smooth: true
			mipmap: true
			fillMode: Image.PreserveAspectFit
			opacity: Calculator.error !== "" ? 0.4 : 1
			Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
		}
	}

	// ── History ──────────────────────────────────────────────────────────
	SectionLabel {
		visible: Calculator.history.length > 0
		text: "History"
	}

	ScrollList {
		visible: Calculator.history.length > 0
		maxHeight: 200

		Repeater {
			model: Calculator.history
			delegate: MenuRow {
				required property var modelData
				icon: "󰋚"
				text: modelData.result
				subtext: modelData.expression
				onActivated: popup.reinsert(modelData.expression)
				onAltActivated: {
					Calculator.copy(modelData.result);
					popup.showCopied("result");
				}
			}
		}
	}
}
