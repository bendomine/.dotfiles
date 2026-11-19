import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Launcher pill + popup (quickshell:toggle-launcher): shortcuts to the other bar
// popups, a grid of quick actions and a keybinding cheat sheet, all built from
// `hyprctl binds -j`. Only binds with a description are listed; descriptions are
// "<Category>: <action>" (see hypr/hyprland.lua), binds sharing a description are
// merged into one row. "Shell" binds form the bar section at the top (minus the
// launcher itself and binds already shown as a tile).
// Shift+Return / right click on the Screenshot tile annotates instead of copying.
StatusBox {
	id: root

	readonly property var actions: [
		{ icon: "󰀻", label: "Apps", bind: "Apps: App launcher", command: ["rofi", "-show", "combi", "-modes", "combi,drun,window", "-combi-modes", "drun,run"] },
		{ icon: "󰖲", label: "Windows", bind: "Apps: Window switcher", command: ["rofi", "-show", "window"] },
		{ icon: "󰃬", label: "Calculator", bind: "Apps: Calculator", command: ["sh", "-c", "~/.config/rofi/calc.sh"] },
		{ icon: "󰆍", label: "Terminal", bind: "Apps: Terminal", command: ["kitty"] },
		{ icon: "󰉋", label: "Files", bind: "Apps: File manager", command: ["dolphin"] },
		{ icon: "", label: "Emacs", bind: "Apps: Emacs (client)", command: ["emacsclient", "-c"] },
		{ icon: "󰹑", label: "Screenshot", bind: "Screenshots: Copy area", delay: 300, command: ["grimblast", "copy", "area"], altCommand: ["sh", "-c", "GRIMBLAST_EDITOR=\"satty --filename\" grimblast edit area"] },
		{ icon: "󰸉", label: "Wallpaper", bind: "Shell: New wallpaper", command: ["systemctl", "--user", "start", "wallpaper.service"] }
	]

	readonly property string launcherBind: "Shell: Launcher / keybinding help"

	// Bar section entries by bind description: icon and the popup to open
	// (`popup`: Popups shortcut name) or `bar` to toggle the bar.
	readonly property var shellTargets: ({
		"Shell: Bluetooth": { icon: "󰂯", popup: "toggle-bluetooth" },
		"Shell: System tray": { icon: "󱊖", popup: "toggle-tray" },
		"Shell: Audio": { icon: "󰓃", popup: "toggle-audio" },
		"Shell: Network": { icon: "󰖩", popup: "toggle-network" },
		"Shell: Media player": { icon: "󰝚", popup: "toggle-media" },
		"Shell: Calendar": { icon: "󰃭", popup: "toggle-calendar" },
		"Shell: System": { icon: "󰘚", popup: "toggle-system" },
		"Shell: Power menu": { icon: "󰐥", popup: "toggle-power" },
		"Shell: Toggle bar": { icon: "󱔓", bar: true }
	})

	// Display order of keybinding categories ("Shell" is the bar section); unknown
	// ones follow in config order.
	readonly property var categoryOrder: ["Apps", "Windows", "Focus", "Layout", "Workspaces", "Media", "Hardware", "Screenshots", "Session"]

	// Hyprland modmask bits (wlr modifiers), in display order.
	readonly property var modifierBits: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"], [2, "Caps"], [16, "Mod2"], [32, "Mod3"], [128, "Mod5"]]

	readonly property var keyNames: ({
		"slash": "/", "backslash": "\\", "bracketleft": "[", "bracketright": "]",
		"braceleft": "{", "braceright": "}", "parenleft": "(", "parenright": ")",
		"comma": ",", "period": ".", "minus": "-", "equal": "=", "plus": "+",
		"semicolon": ";", "colon": ":", "apostrophe": "'", "grave": "`",
		"space": "Space", "return": "Enter", "escape": "Esc", "tab": "Tab",
		"backspace": "Bksp", "delete": "Del", "print": "Print",
		"left": "←", "right": "→", "up": "↑", "down": "↓",
		"mouse_down": "Scroll↓", "mouse_up": "Scroll↑", "mouse_left": "Scroll←", "mouse_right": "Scroll→",
		"mouse:272": "LMB", "mouse:273": "RMB", "mouse:274": "MMB",
		"xf86audioraisevolume": "Vol+", "xf86audiolowervolume": "Vol−",
		"xf86audiomute": "Mute", "xf86audiomicmute": "Mic Mute",
		"xf86monbrightnessup": "Bright+", "xf86monbrightnessdown": "Bright−",
		"xf86audionext": "Next", "xf86audioprev": "Prev",
		"xf86audioplay": "Play", "xf86audiopause": "Pause", "xf86audiostop": "Stop"
	})

	// First key combo bound to `description`, or "".
	function hintFor(description) {
		const keys = d.keyMap[description];
		return keys && keys.length > 0 ? keys[0] : "";
	}

	function run(action, alt) {
		const command = alt && action.altCommand ? action.altCommand : action.command;
		popup.close();
		if (action.delay) {
			// Let the popup fade out first (e.g. so it is not in the screenshot).
			d.pending = command;
			delayTimer.interval = action.delay;
			delayTimer.restart();
		} else {
			Quickshell.execDetached(command);
		}
	}

	// Bar section entry: open that popup (on this screen) or toggle the bar.
	function runShell(description) {
		const target = shellTargets[description];
		if (!target)
			return;
		if (target.bar) {
			ShellState.barVisible = !ShellState.barVisible;
		} else if (target.popup) {
			const other = Popups.registry.find(p => p.shortcutName === target.popup && p.screenName === popup.screenName) ?? Popups.find(target.popup);
			if (other)
				other.show(false); // Popups closes this one
		}
	}

	function refreshBinds() {
		if (bindsProc.running)
			return;
		if (d.status !== "ok")
			d.status = "loading";
		loadTimeout.restart();
		bindsProc.running = true;
	}

	function modifierNames(mask) {
		return modifierBits.filter(m => (mask & m[0]) !== 0).map(m => m[1]);
	}

	function keyName(bind) {
		const raw = bind.key ?? "";
		if (raw === "")
			return bind.keycode ? "code:" + bind.keycode : "?";
		const lower = raw.toLowerCase();
		if (keyNames[lower] !== undefined)
			return keyNames[lower];
		if (lower.startsWith("xf86"))
			return raw.slice(4);
		if (raw.length === 1)
			return raw.toUpperCase();
		return raw.charAt(0).toUpperCase() + raw.slice(1);
	}

	// Combos → compact labels: keys sharing modifiers stay separate chips, except
	// runs of 3+ single letters/digits, which collapse to "Super+1…0".
	function compactKeys(combos) {
		const byMods = {};
		const order = [];
		for (const c of combos) {
			if (!(c.mods in byMods)) {
				byMods[c.mods] = [];
				order.push(c.mods);
			}
			if (!byMods[c.mods].includes(c.key))
				byMods[c.mods].push(c.key);
		}
		const out = [];
		for (const mods of order) {
			const keys = byMods[mods];
			const prefix = mods !== "" ? mods + "+" : "";
			if (keys.length >= 3 && keys.every(k => /^[0-9A-Z]$/.test(k)))
				out.push(prefix + keys[0] + "…" + keys[keys.length - 1]);
			else
				for (const k of keys)
					out.push(prefix + k);
		}
		return out;
	}

	function parseBinds(text) {
		let binds;
		try {
			binds = JSON.parse(text);
		} catch (e) {
			binds = null;
		}
		if (!Array.isArray(binds)) {
			d.status = "error";
			return;
		}
		const groups = [];
		const byDesc = {};
		for (const b of binds) {
			if (!b.has_description || !b.description)
				continue;
			let g = byDesc[b.description];
			if (!g) {
				const sep = b.description.indexOf(": ");
				g = {
					description: b.description,
					category: sep > 0 ? b.description.slice(0, sep) : "Other",
					action: sep > 0 ? b.description.slice(sep + 2) : b.description,
					combos: []
				};
				byDesc[b.description] = g;
				groups.push(g);
			}
			g.combos.push({ mods: modifierNames(b.modmask ?? 0).join("+"), key: keyName(b) });
		}

		const keyMap = {};
		const sections = [];
		const sectionOf = {};
		const shellEntries = [];
		const tileBinds = actions.map(a => a.bind);
		for (const g of groups) {
			const keys = compactKeys(g.combos);
			keyMap[g.description] = keys;
			if (g.category === "Shell") {
				if (g.description !== launcherBind && !tileBinds.includes(g.description))
					shellEntries.push({ description: g.description, action: g.action, keys: keys });
				continue;
			}
			let s = sectionOf[g.category];
			if (!s) {
				const rank = categoryOrder.indexOf(g.category);
				s = { category: g.category, rank: rank >= 0 ? rank : categoryOrder.length + sections.length, rows: [] };
				sectionOf[g.category] = s;
				sections.push(s);
			}
			s.rows.push({ action: g.action, keys: keys });
		}
		sections.sort((a, b) => a.rank - b.rank);
		d.keyMap = keyMap;
		d.shellEntries = shellEntries;
		d.sections = sections;
		d.status = "ok";
	}

	QtObject {
		id: d
		property string status: "idle" // idle | loading | ok | error
		property var sections: []
		property var shellEntries: []
		property var keyMap: ({})
		property var pending: []
		property string hostname: ""
	}

	Process {
		id: bindsProc
		command: ["hyprctl", "binds", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				loadTimeout.stop();
				root.parseBinds(text);
			}
		}
		onExited: exitCode => {
			if (exitCode !== 0) {
				loadTimeout.stop();
				d.status = "error";
			}
		}
	}

	// hyprctl missing or hanging.
	Timer {
		id: loadTimeout
		interval: 3000
		onTriggered: {
			if (d.status === "loading")
				d.status = "error";
		}
	}

	Timer {
		id: delayTimer
		onTriggered: Quickshell.execDetached(d.pending)
	}

	FileView {
		path: "/etc/hostname"
		printErrors: false
		onLoaded: d.hostname = text().trim()
	}

	// ── Pill ─────────────────────────────────────────────────────────────
	active: popup.open
	// Circular pill: logo box plus equal padding fills the pill height.
	padding: (Theme.pillHeight - logo.implicitWidth) / 2

	// The font's line box puts the glyph's ink above center, so center the visible
	// ink (tight bounds) in a square box instead; rotation then pivots on the logo's
	// own center rather than wobbling.
	Item {
		id: logo
		implicitWidth: Theme.iconSizeLarge
		implicitHeight: Theme.iconSizeLarge
		rotation: root.hovered ? 60 : 0
		Behavior on rotation { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack } }

		Glyph {
			id: logoGlyph
			text: "󱄅"
			font.pixelSize: Theme.iconSizeLarge
			color: root.active ? root.fg : Theme.accent
			horizontalAlignment: Text.AlignLeft
			// Ink center relative to the text item's origin (baseline sits at ascent).
			x: logo.width / 2 - (logoInk.tightBoundingRect.x + logoInk.tightBoundingRect.width / 2)
			y: logo.height / 2 - (logoFont.ascent + logoInk.tightBoundingRect.y + logoInk.tightBoundingRect.height / 2)
		}
		TextMetrics {
			id: logoInk
			font: logoGlyph.font
			text: logoGlyph.text
		}
		FontMetrics {
			id: logoFont
			font: logoGlyph.font
		}
	}

	// Rounded key-combo label.
	component KeyChip: Rectangle {
		id: chip
		property string label: ""
		implicitWidth: chipText.implicitWidth + 12
		implicitHeight: 20
		radius: 6
		color: Theme.surfaceVariant
		border.width: 1
		border.color: Theme.alpha(Theme.border, 0.9)
		StyledText {
			id: chipText
			anchors.centerIn: parent
			text: chip.label
			font.pixelSize: Theme.fontSizeSmall
		}
	}

	// ── Popup ────────────────────────────────────────────────────────────
	BarPopup {
		id: popup
		anchorItem: root
		shortcutName: "toggle-launcher"
		contentWidth: 440
		// Bar list (2 columns), tile grid (4 columns) and keybinding list are stacked
		// vertically: navigate geometrically.
		spatialNav: true

		onOpenChanged: {
			if (open)
				root.refreshBinds();
		}

		PopupHeader {
			icon: "󱄅"
			title: "NixOS"
			subtitle: {
				const user = Quickshell.env("USER") ?? "";
				return d.hostname !== "" ? (user !== "" ? user + "@" + d.hostname : d.hostname) : user;
			}
			KeyChip {
				visible: label !== ""
				label: root.hintFor(root.launcherBind)
			}
		}

		SectionLabel {
			visible: d.shellEntries.length > 0
			text: "Bar"
		}

		GridLayout {
			id: barGrid
			visible: d.shellEntries.length > 0
			Layout.fillWidth: true
			Layout.bottomMargin: Theme.spacingSmall
			columns: 2
			columnSpacing: Theme.spacingSmall
			rowSpacing: 2

			Repeater {
				model: d.shellEntries
				delegate: MenuRow {
					id: entry
					required property var modelData
					readonly property var target: root.shellTargets[modelData.description]
					Layout.preferredWidth: (popup.contentWidth - barGrid.columnSpacing) / 2
					compact: true
					icon: target ? target.icon : "󰌌"
					text: modelData.action
					onActivated: root.runShell(modelData.description)

					KeyChip {
						visible: label !== ""
						label: entry.modelData.keys.length > 0 ? entry.modelData.keys[0] : ""
					}
				}
			}
		}

		GridLayout {
			id: grid
			Layout.fillWidth: true
			columns: 4
			columnSpacing: Theme.spacingSmall
			rowSpacing: Theme.spacingSmall

			Repeater {
				model: root.actions
				delegate: Rectangle {
					id: tile
					required property var modelData
					readonly property string hint: root.hintFor(modelData.bind)
					property bool navigable: true
					property bool keyFocused: false
					readonly property bool hovered: tileHover.hovered
					readonly property bool highlighted: keyFocused || hovered

					function activate() {
						root.run(modelData, false);
					}
					function activateAlt() {
						root.run(modelData, true);
					}

					Layout.preferredWidth: (popup.contentWidth - (grid.columns - 1) * grid.columnSpacing) / grid.columns
					implicitHeight: 60
					radius: Theme.radiusSmall
					color: highlighted ? Theme.surfaceVariant : Theme.alpha(Theme.surfaceVariant, 0.35)
					border.width: 1
					border.color: keyFocused ? Theme.alpha(Theme.accent, 0.7) : "transparent"
					Behavior on color { ColorAnimation { duration: Theme.animFast } }

					HoverHandler {
						id: tileHover
						cursorShape: Qt.PointingHandCursor
						onHoveredChanged: {
							if (hovered)
								popup.setFocusItem(tile);
							else if (popup.focusItem === tile)
								popup.setFocusItem(null);
						}
					}

					TapHandler {
						acceptedButtons: Qt.LeftButton | Qt.RightButton
						onTapped: (eventPoint, button) => {
							if (button === Qt.RightButton)
								tile.activateAlt();
							else
								tile.activate();
						}
					}

					ColumnLayout {
						anchors.centerIn: parent
						width: parent.width - 2 * Theme.spacingSmall
						spacing: 1

						Glyph {
							Layout.alignment: Qt.AlignHCenter
							text: tile.modelData.icon
							font.pixelSize: Theme.iconSizeLarge
							color: tile.highlighted ? Theme.accent : Theme.foreground
						}
						StyledText {
							Layout.fillWidth: true
							horizontalAlignment: Text.AlignHCenter
							text: tile.modelData.label
							font.pixelSize: Theme.fontSizeSmall
							elide: Text.ElideRight
						}
						StyledText {
							Layout.fillWidth: true
							visible: tile.hint !== ""
							horizontalAlignment: Text.AlignHCenter
							text: tile.hint
							font.pixelSize: Theme.fontSizeSmall - 1
							color: Theme.foregroundMuted
							elide: Text.ElideRight
						}
					}
				}
			}
		}

		Separator {}

		StyledText {
			Layout.fillWidth: true
			Layout.margins: Theme.spacing
			visible: d.sections.length === 0
			text: d.status === "error" ? "Couldn't read keybindings from hyprctl" : (d.status === "ok" ? "No keybindings with descriptions" : "Loading keybindings…")
			font.pixelSize: Theme.fontSizeSmall
			color: Theme.foregroundMuted
			horizontalAlignment: Text.AlignHCenter
		}

		ScrollList {
			visible: d.sections.length > 0
			maxHeight: 240

			Repeater {
				model: d.sections
				delegate: ColumnLayout {
					id: section
					required property var modelData
					Layout.fillWidth: true
					spacing: 2

					SectionLabel {
						text: section.modelData.category
					}

					Repeater {
						model: section.modelData.rows
						delegate: MenuRow {
							id: row
							required property var modelData
							compact: true
							text: row.modelData.action

							Repeater {
								model: row.modelData.keys
								delegate: KeyChip {
									required property string modelData
									label: modelData
								}
							}
						}
					}
				}
			}
		}
	}
}
