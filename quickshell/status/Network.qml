import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Network pill + popup (quickshell:toggle-network), backed by Quickshell.Networking
// (NetworkManager). Activating a network connects to it: saved and open networks
// directly, unknown WPA/WPA3-personal networks after an inline password prompt
// (Return submits, Escape cancels). Shift+Return / o / m / right click open a
// Connect/Disconnect/Forget menu.
StatusBox {
	id: root
	readonly property var devices: Networking.devices.values
	readonly property var wifiDevice: devices.find(dev => dev.type === DeviceType.Wifi) ?? null
	readonly property var wiredDevice: devices.find(dev => dev.type === DeviceType.Wired && dev.connected) ?? null
	readonly property bool wifiOn: Networking.wifiEnabled
	readonly property var allNetworks: wifiDevice && wifiOn ? wifiDevice.networks.values : []
	readonly property var activeNetwork: allNetworks.find(n => n.connected) ?? null
	// Connected first, then by signal strength (5% buckets keep the order stable).
	readonly property var sortedNetworks: allNetworks.filter(n => n.name !== "").sort((a, b) => (b.connected - a.connected) || (Math.round(b.signalStrength * 20) - Math.round(a.signalStrength * 20)) || a.name.localeCompare(b.name))
	readonly property bool connecting: wifiDevice !== null && wifiDevice.state === ConnectionState.Connecting

	function strengthIcon(s) {
		if (s >= 0.75)
			return "󰤨";
		if (s >= 0.5)
			return "󰤥";
		if (s >= 0.25)
			return "󰤢";
		return "󰤟";
	}

	function isSecure(n) {
		return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe && n.security !== WifiSecurityType.Unknown;
	}

	function usesPsk(n) {
		return n.security === WifiSecurityType.WpaPsk || n.security === WifiSecurityType.Wpa2Psk || n.security === WifiSecurityType.Sae;
	}

	function securityName(n) {
		switch (n.security) {
		case WifiSecurityType.Sae:
			return "WPA3";
		case WifiSecurityType.Wpa2Psk:
			return "WPA2";
		case WifiSecurityType.WpaPsk:
			return "WPA";
		case WifiSecurityType.Wpa2Eap:
		case WifiSecurityType.WpaEap:
		case WifiSecurityType.Wpa3SuiteB192:
			return "Enterprise";
		case WifiSecurityType.StaticWep:
		case WifiSecurityType.DynamicWep:
			return "WEP";
		case WifiSecurityType.Leap:
			return "LEAP";
		case WifiSecurityType.Owe:
			return "Enhanced open";
		case WifiSecurityType.Open:
			return "Open";
		}
		return "";
	}

	function networkStatus(n) {
		if (n.state === ConnectionState.Connecting)
			return "Connecting…";
		if (n.state === ConnectionState.Disconnecting)
			return "Disconnecting…";
		if (n.connected)
			return "Connected";
		const sec = securityName(n);
		if (n.known)
			return sec !== "" ? "Saved · " + sec : "Saved";
		return sec;
	}

	function failText(reason) {
		switch (reason) {
		case ConnectionFailReason.NoSecrets:
			return "password required or incorrect";
		case ConnectionFailReason.WifiClientDisconnected:
			return "disconnected by the access point";
		case ConnectionFailReason.WifiAuthTimeout:
			return "authentication timed out";
		case ConnectionFailReason.WifiNetworkLost:
			return "network lost";
		}
		return "connection failed";
	}

	function connectTo(n) {
		d.error = "";
		if (!n || n.connected || n.stateChanging)
			return;
		if (n.known || !isSecure(n)) {
			d.pending = n;
			n.connect();
		} else if (usesPsk(n)) {
			d.passwordFor = n;
		} else {
			d.error = n.name + ": " + securityName(n) + " networks must be set up with nmtui or nm-connection-editor";
		}
	}

	function submitPassword(n, psk, row) {
		if (psk.length < 8 || psk.length > 63) {
			d.error = "WPA passwords are 8 to 63 characters long";
			return;
		}
		closePrompt(row);
		d.error = "";
		d.pending = n;
		n.connectWithPsk(psk);
	}

	// Give keyboard focus back to the popup's key handler (the FocusScope inside the
	// BarPopup panel) so its navigation keys work again.
	function releaseInput(item) {
		for (let p = item; p; p = p.parent) {
			if (p.parent && p.parent.barPopup !== undefined) {
				p.forceActiveFocus();
				return;
			}
		}
	}

	// Hide the password prompt below `row` and move the keyboard cursor back to it.
	function closePrompt(row) {
		releaseInput(row);
		if (row.visible)
			popup.setFocusItem(row);
		d.passwordFor = null;
	}

	function networkActions(n) {
		return [
			{
				text: n.connected ? "Disconnect" : "Connect",
				icon: n.connected ? "󰌙" : "󰌘",
				action: () => {
					if (n.connected)
						n.disconnect();
					else
						root.connectTo(n);
				}
			},
			{
				text: "Forget",
				icon: "󰧧",
				danger: true,
				enabled: n.known,
				action: () => n.forget()
			}
		];
	}

	QtObject {
		id: d
		property var pending: null // network a connection attempt is running for
		property var passwordFor: null // network whose password prompt is open
		property string error: ""
	}

	Connections {
		target: d.pending
		ignoreUnknownSignals: true
		function onConnectionFailed(reason) {
			const n = d.pending;
			d.pending = null;
			d.error = n.name + ": " + root.failText(reason);
			if (reason === ConnectionFailReason.NoSecrets && root.usesPsk(n))
				d.passwordFor = n;
		}
		function onConnectedChanged() {
			if (d.pending && d.pending.connected) {
				d.pending = null;
				d.error = "";
			}
		}
	}

	// Scan for networks while the popup is open.
	Binding {
		when: root.wifiDevice !== null
		target: root.wifiDevice
		property: "scannerEnabled"
		value: popup.open && root.wifiOn
	}

	active: popup.open
	spacing: Theme.spacingSmall

	Glyph {
		text: {
			if (root.wiredDevice)
				return "󰈀";
			if (root.activeNetwork)
				return root.strengthIcon(root.activeNetwork.signalStrength);
			if (!root.wifiDevice)
				return "󰌙";
			if (!root.wifiOn)
				return "󰖪";
			return root.connecting ? "󰤯" : "󰤮";
		}
		color: root.wiredDevice || root.activeNetwork ? root.fg : root.fgMuted
	}
	StyledText {
		visible: text !== ""
		Layout.maximumWidth: 110
		text: root.activeNetwork ? root.activeNetwork.name : (root.wiredDevice ? "" : (root.connecting ? "Connecting…" : ""))
		elide: Text.ElideRight
		color: root.fg
	}

	// Small labelled button used as a trailing widget in rows.
	component ActionChip: Rectangle {
		id: chip
		property string icon: ""
		property string label: ""
		property color tint: Theme.foregroundMuted
		signal clicked()
		implicitWidth: chipRow.implicitWidth + 2 * Theme.spacing
		implicitHeight: 24
		radius: height / 2
		color: chipMouse.containsMouse ? Theme.alpha(chip.tint, 0.18) : "transparent"
		border.width: 1
		border.color: Theme.alpha(chip.tint, 0.5)
		Behavior on color { ColorAnimation { duration: Theme.animFast } }

		RowLayout {
			id: chipRow
			anchors.centerIn: parent
			spacing: Theme.spacingSmall
			Glyph {
				visible: chip.icon !== ""
				text: chip.icon
				font.pixelSize: Theme.fontSizeSmall + 1
				color: chip.tint
			}
			StyledText {
				text: chip.label
				font.pixelSize: Theme.fontSizeSmall
				color: chip.tint
			}
		}
		// MouseArea (not a TapHandler) so the click does not also activate the row.
		MouseArea {
			id: chipMouse
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: chip.clicked()
		}
	}

	BarPopup {
		id: popup
		anchorItem: root
		shortcutName: "toggle-network"
		contentWidth: 320

		onOpenChanged: {
			if (!open) {
				d.passwordFor = null;
				d.error = "";
			}
		}

		PopupHeader {
			icon: "󰖩"
			title: "Network"
			subtitle: {
				if (root.activeNetwork)
					return "Connected to " + root.activeNetwork.name;
				if (root.wiredDevice)
					return "Ethernet connected";
				if (!root.wifiDevice)
					return "No Wi-Fi device";
				if (!root.wifiOn)
					return "Wi-Fi off";
				return root.connecting ? "Connecting…" : "Not connected";
			}
		}

		MenuRow {
			visible: root.wifiDevice !== null
			icon: root.wifiOn ? "󰖩" : "󰖪"
			text: "Wi-Fi"
			subtext: Networking.wifiHardwareEnabled ? "" : "Disabled by hardware switch"
			selected: root.wifiOn
			enabled: Networking.wifiHardwareEnabled
			onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
			Toggle {
				checked: root.wifiOn
				onToggled: value => Networking.wifiEnabled = value
			}
		}

		RowLayout {
			Layout.fillWidth: true
			Layout.leftMargin: Theme.spacing
			Layout.rightMargin: Theme.spacing
			visible: d.error !== ""
			spacing: Theme.spacing
			Glyph {
				Layout.alignment: Qt.AlignTop
				text: "󰀦"
				color: Theme.urgent
			}
			StyledText {
				Layout.fillWidth: true
				text: d.error
				color: Theme.urgent
				font.pixelSize: Theme.fontSizeSmall
				wrapMode: Text.Wrap
			}
		}

		SectionLabel {
			text: "Connected"
			visible: root.wiredDevice !== null || root.activeNetwork !== null
		}

		MenuRow {
			id: wiredRow
			visible: root.wiredDevice !== null
			icon: "󰈀"
			text: root.wiredDevice ? "Ethernet (" + root.wiredDevice.name + ")" : ""
			subtext: root.wiredDevice && root.wiredDevice.linkSpeed > 0 ? "Connected · " + root.wiredDevice.linkSpeed + " Mb/s" : "Connected"
			selected: true
			onActivated: root.wiredDevice.disconnect()
			ActionChip {
				icon: "󰌙"
				label: "Disconnect"
				tint: wiredRow.highlighted ? Theme.urgent : Theme.foregroundMuted
				onClicked: wiredRow.activate()
			}
		}

		MenuRow {
			id: currentRow
			visible: root.activeNetwork !== null
			icon: root.activeNetwork ? root.strengthIcon(root.activeNetwork.signalStrength) : ""
			text: root.activeNetwork ? root.activeNetwork.name : ""
			subtext: root.activeNetwork ? root.networkStatus(root.activeNetwork) + " · " + Math.round(root.activeNetwork.signalStrength * 100) + "%" : ""
			selected: true
			onActivated: root.activeNetwork.disconnect()
			onAltActivated: netMenu.show(currentRow, root.networkActions(root.activeNetwork))
			ActionChip {
				icon: "󰌙"
				label: "Disconnect"
				tint: currentRow.highlighted ? Theme.urgent : Theme.foregroundMuted
				onClicked: currentRow.activate()
			}
		}

		Separator {
			visible: root.wifiOn && root.wifiDevice !== null
		}

		RowLayout {
			Layout.fillWidth: true
			visible: root.wifiOn && root.wifiDevice !== null
			SectionLabel {
				text: "Available networks"
			}
			StyledText {
				Layout.rightMargin: Theme.spacing
				visible: root.wifiDevice !== null && root.wifiDevice.scannerEnabled
				text: "Scanning…"
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.foregroundMuted
			}
		}

		ScrollList {
			visible: root.wifiOn && root.wifiDevice !== null
			maxHeight: 320

			Repeater {
				id: networkRepeater
				model: ScriptModel {
					values: root.sortedNetworks
				}
				delegate: ColumnLayout {
					id: entry
					required property var modelData
					readonly property bool prompting: d.passwordFor === modelData
					Layout.fillWidth: true
					spacing: 2

					MenuRow {
						id: netRow
						icon: root.strengthIcon(entry.modelData.signalStrength)
						text: entry.modelData.name
						subtext: root.networkStatus(entry.modelData)
						selected: entry.modelData.connected
						onActivated: root.connectTo(entry.modelData)
						onAltActivated: netMenu.show(netRow, root.networkActions(entry.modelData))

						Glyph {
							visible: root.isSecure(entry.modelData)
							text: "󰌾"
							font.pixelSize: Theme.fontSizeSmall + 1
							color: Theme.foregroundMuted
						}
						StyledText {
							Layout.minimumWidth: 32
							horizontalAlignment: Text.AlignRight
							text: Math.round(entry.modelData.signalStrength * 100) + "%"
							font.pixelSize: Theme.fontSizeSmall
							color: Theme.foregroundMuted
						}
					}

					// Inline password prompt (navigable; Return/Space focuses the input).
					Rectangle {
						id: pwBox
						property bool navigable: true
						property bool keyFocused: false
						function activate() {
							pwInput.forceActiveFocus();
						}

						visible: entry.prompting
						Layout.fillWidth: true
						Layout.leftMargin: Theme.spacing
						implicitHeight: 34
						radius: Theme.radiusSmall
						color: Theme.alpha(Theme.background, 0.6)
						border.width: pwInput.activeFocus || keyFocused ? 2 : 1
						border.color: pwInput.activeFocus || keyFocused ? Theme.accent : Theme.border
						Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

						onVisibleChanged: {
							if (!visible)
								return;
							pwInput.text = "";
							Qt.callLater(() => {
								if (!pwBox.visible)
									return;
								pwInput.forceActiveFocus();
								popup.setFocusItem(pwBox);
							});
						}

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: Theme.spacing
							anchors.rightMargin: 5
							spacing: Theme.spacing

							Glyph {
								text: "󰌾"
								font.pixelSize: Theme.fontSizeLarge
								color: pwInput.activeFocus ? Theme.accent : Theme.foregroundMuted
							}

							Item {
								Layout.fillWidth: true
								Layout.fillHeight: true

								TextInput {
									id: pwInput
									anchors.fill: parent
									verticalAlignment: TextInput.AlignVCenter
									echoMode: TextInput.Password
									passwordCharacter: "•"
									clip: true
									font.family: Theme.fontFamily
									font.pixelSize: Theme.fontSize
									color: Theme.foreground
									selectionColor: Theme.accent
									selectedTextColor: Theme.onAccent
									selectByMouse: true

									Keys.onPressed: event => {
										switch (event.key) {
										case Qt.Key_Escape:
											root.closePrompt(netRow);
											event.accepted = true;
											break;
										case Qt.Key_Return:
										case Qt.Key_Enter:
											root.submitPassword(entry.modelData, pwInput.text, netRow);
											event.accepted = true;
											break;
										case Qt.Key_Up:
										case Qt.Key_Down:
										case Qt.Key_Tab:
										case Qt.Key_Backtab:
											// Leave the input (prompt stays open); the popup navigation handles the key.
											root.releaseInput(pwBox);
											event.accepted = false;
											break;
										}
									}
								}

								StyledText {
									anchors.fill: parent
									visible: pwInput.text === ""
									text: "Password for " + entry.modelData.name
									elide: Text.ElideRight
									color: Theme.foregroundMuted
								}
							}

							ActionChip {
								label: "Connect"
								tint: Theme.accent
								onClicked: root.submitPassword(entry.modelData, pwInput.text, netRow)
							}
						}
					}
				}
			}

			StyledText {
				Layout.fillWidth: true
				Layout.margins: Theme.spacing
				visible: networkRepeater.count === 0
				text: "Searching for networks…"
				color: Theme.foregroundMuted
				horizontalAlignment: Text.AlignHCenter
			}
		}

		overlay: ContextMenu {
			id: netMenu
		}
	}
}
