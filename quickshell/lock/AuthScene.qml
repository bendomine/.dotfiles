import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import "../shared"
import ".."

// The lock-screen look, shared by the session lock (LockSurface) and the login
// greeter (greeter/Greeter.qml): blurred, theme-tinted wallpaper, a large clock
// and date, and a centered card styled like a bar popup with the user, the
// password field and a status line. Fades in from the background color.
//   Enter  submit        Escape  clear
// All state lives in `auth`, so several scenes (one per screen) can share one
// field; whichever has keyboard focus edits it. `auth` provides:
//   password: string        typed text (two-way with the field)
//   busy: bool              checking a response (pulse + spinner, read-only field)
//   status: string          message or failure reason ("" shows `hint`)
//   statusIsError: bool
//   capsLock: bool          (also written by the field from typed letters)
//   failures: int           bumped on every failure (drives the shake)
//   user, facePath, wallpaperPath: string     now: date
//   submit(), clear(), probeCaps()
Item {
	id: root
	required property var auth
	// Status line when there is nothing else to say.
	property string hint: "Enter to submit · Esc to clear"
	// For callers placing extra content around the card (e.g. a session line).
	readonly property Item card: cardItem

	opacity: 0
	Component.onCompleted: fadeIn.start()

	NumberAnimation {
		id: fadeIn
		target: root
		property: "opacity"
		to: 1
		duration: Theme.animNormal
		easing.type: Easing.OutCubic
	}

	// Clicking anywhere returns focus to the password field.
	MouseArea {
		anchors.fill: parent
		onPressed: input.forceActiveFocus()
	}

	// ── Background ───────────────────────────────────────────────────
	Image {
		id: wallpaper
		anchors.fill: parent
		visible: false
		source: root.auth.wallpaperPath !== "" ? "file://" + root.auth.wallpaperPath : ""
		fillMode: Image.PreserveAspectCrop
		// Blurred anyway: a quarter-resolution texture is plenty and cheap.
		sourceSize.width: Math.max(1, root.width / 4)
		sourceSize.height: Math.max(1, root.height / 4)
		asynchronous: true
		cache: false
	}

	MultiEffect {
		anchors.fill: parent
		source: wallpaper
		visible: wallpaper.status === Image.Ready
		autoPaddingEnabled: false
		blurEnabled: true
		blur: 1
		blurMax: 48
		saturation: -0.15
	}

	Rectangle {
		anchors.fill: parent
		color: Theme.alpha(Theme.background, Theme.dark ? 0.55 : 0.45)
	}

	// ── Clock ────────────────────────────────────────────────────────
	ColumnLayout {
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.bottom: cardItem.top
		anchors.bottomMargin: Math.min(96, root.height * 0.08)
		spacing: 0

		RowLayout {
			Layout.alignment: Qt.AlignHCenter
			spacing: Theme.spacing

			StyledText {
				// Qt only uses 12-hour "h" when AP is in the same format string; strip the
				// suffix here since AM/PM is shown separately beside it.
				text: Qt.formatTime(root.auth.now, "h:mm AP").replace(/\s*[AP]M$/i, "")
				font.pixelSize: 112
				font.weight: Font.Bold
			}
			StyledText {
				Layout.alignment: Qt.AlignBottom
				Layout.bottomMargin: 22
				text: Qt.formatTime(root.auth.now, "AP")
				font.pixelSize: 28
				font.weight: Font.DemiBold
				color: Theme.accent
			}
		}
		StyledText {
			Layout.alignment: Qt.AlignHCenter
			text: Qt.formatDate(root.auth.now, "dddd, d MMMM")
			font.pixelSize: 22
			color: Theme.foregroundMuted
		}
	}

	// ── Card ─────────────────────────────────────────────────────────
	Item {
		id: cardItem
		readonly property real cardWidth: 340
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.verticalCenter: parent.verticalCenter
		anchors.verticalCenterOffset: root.height * 0.06
		width: cardWidth
		height: column.implicitHeight + 2 * Theme.spacingLarge * 2
		transform: Translate {
			id: shake
		}

		SequentialAnimation {
			id: shakeAnim
			NumberAnimation { target: shake; property: "x"; to: -12; duration: 50; easing.type: Easing.OutQuad }
			NumberAnimation { target: shake; property: "x"; to: 10; duration: 70; easing.type: Easing.InOutQuad }
			NumberAnimation { target: shake; property: "x"; to: -7; duration: 60; easing.type: Easing.InOutQuad }
			NumberAnimation { target: shake; property: "x"; to: 4; duration: 50; easing.type: Easing.InOutQuad }
			NumberAnimation { target: shake; property: "x"; to: 0; duration: 40; easing.type: Easing.OutQuad }
		}

		Connections {
			target: root.auth
			function onFailuresChanged() {
				shakeAnim.restart();
			}
		}

		RectangularShadow {
			anchors.fill: panel
			radius: panel.radius
			offset.y: 4
			blur: 24
			spread: 0
			color: Theme.alpha("#000000", Theme.dark ? 0.45 : 0.22)
		}

		Rectangle {
			id: panel
			anchors.fill: parent
			radius: Theme.radius
			color: Theme.alpha(Theme.surface, Theme.panelOpacity)
			border.width: 1
			border.color: Theme.alpha(Theme.border, 0.9)

			ColumnLayout {
				id: column
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.top: parent.top
				anchors.margins: Theme.spacingLarge * 2
				spacing: Theme.spacing

				// Avatar: `facePath` if present, else an account glyph.
				Rectangle {
					Layout.alignment: Qt.AlignHCenter
					implicitWidth: 72
					implicitHeight: 72
					radius: width / 2
					color: Theme.alpha(Theme.accent, 0.18)
					border.width: 2
					border.color: Theme.alpha(Theme.accent, 0.5)

					Glyph {
						anchors.centerIn: parent
						visible: face.status !== Image.Ready
						text: "󰀄"
						font.pixelSize: 38
						color: Theme.accent
					}

					Image {
						id: face
						anchors.fill: parent
						anchors.margins: 3
						visible: false
						source: root.auth.facePath !== "" ? "file://" + root.auth.facePath : ""
						sourceSize.width: 144
						sourceSize.height: 144
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						cache: false
					}

					Rectangle {
						id: faceMask
						anchors.fill: face
						radius: width / 2
						visible: false
						layer.enabled: true
					}

					MultiEffect {
						anchors.fill: face
						source: face
						visible: face.status === Image.Ready
						maskEnabled: true
						maskSource: faceMask
					}
				}

				StyledText {
					Layout.alignment: Qt.AlignHCenter
					Layout.topMargin: Theme.spacingSmall
					text: root.auth.user
					font.pixelSize: Theme.fontSizeLarge + 3
					font.weight: Font.Bold
				}

				// ── Password field ───────────────────────────────────
				Rectangle {
					id: field
					Layout.fillWidth: true
					Layout.topMargin: Theme.spacing
					implicitHeight: 42
					radius: height / 2
					color: Theme.surfaceVariant
					border.width: input.activeFocus ? 2 : 1
					border.color: root.auth.statusIsError ? Theme.urgent : (input.activeFocus ? Theme.accent : Theme.border)
					Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

					// Pulse while checking.
					SequentialAnimation on opacity {
						running: root.auth.busy
						loops: Animation.Infinite
						alwaysRunToEnd: true
						NumberAnimation { to: 0.6; duration: Theme.animSlow; easing.type: Easing.InOutSine }
						NumberAnimation { to: 1; duration: Theme.animSlow; easing.type: Easing.InOutSine }
					}

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: Theme.spacingLarge + 2
						anchors.rightMargin: Theme.spacingLarge + 2
						spacing: Theme.spacing

						// Lock icon; a spinning loader while authenticating.
						Item {
							implicitWidth: Theme.iconSizeLarge
							implicitHeight: Theme.iconSizeLarge

							Glyph {
								anchors.centerIn: parent
								visible: !root.auth.busy
								text: "󰌾"
								font.pixelSize: Theme.fontSizeLarge + 1
								color: input.activeFocus ? Theme.accent : Theme.foregroundMuted
							}

							// Geometric arc rather than a font glyph: a glyph's ink is not
							// centered in its Text box, so it wobbles when rotated. The
							// square's center is the arc's center, so it spins in place.
							Item {
								id: spinner
								anchors.centerIn: parent
								width: Theme.fontSizeLarge + 1
								height: width
								visible: root.auth.busy

								Shape {
									anchors.fill: parent
									preferredRendererType: Shape.CurveRenderer

									ShapePath {
										strokeColor: Theme.accent
										strokeWidth: 2
										fillColor: "transparent"
										capStyle: ShapePath.RoundCap

										PathAngleArc {
											centerX: spinner.width / 2
											centerY: spinner.height / 2
											radiusX: spinner.width / 2 - 1
											radiusY: spinner.height / 2 - 1
											startAngle: 0
											sweepAngle: 270
										}
									}
								}

								RotationAnimator on rotation {
									running: root.auth.busy
									loops: Animation.Infinite
									from: 0
									to: 360
									duration: 900
								}
							}
						}

						Item {
							Layout.fillWidth: true
							Layout.fillHeight: true

							TextInput {
								id: input
								anchors.fill: parent
								focus: true
								readOnly: root.auth.busy
								verticalAlignment: TextInput.AlignVCenter
								horizontalAlignment: TextInput.AlignHCenter
								echoMode: TextInput.Password
								passwordCharacter: "•"
								passwordMaskDelay: 0
								clip: true
								font.family: Theme.fontFamily
								font.pixelSize: Theme.fontSizeLarge
								font.letterSpacing: 2
								color: Theme.foreground
								selectionColor: Theme.accent
								selectedTextColor: Theme.onAccent
								inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
								Component.onCompleted: forceActiveFocus()

								onTextEdited: root.auth.password = text

								Connections {
									target: root.auth
									function onPasswordChanged() {
										if (input.text !== root.auth.password)
											input.text = root.auth.password;
									}
								}

								Keys.onPressed: event => {
									switch (event.key) {
									case Qt.Key_Return:
									case Qt.Key_Enter:
										root.auth.submit();
										event.accepted = true;
										return;
									case Qt.Key_Escape:
										root.auth.clear();
										event.accepted = true;
										return;
									}
									// Infer caps lock from typed letters: uppercase without Shift
									// (or lowercase with it) means it is on.
									const t = event.text;
									if (t.length === 1 && t.toLowerCase() !== t.toUpperCase()) {
										const upper = t !== t.toLowerCase();
										const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
										root.auth.capsLock = upper !== shift;
									}
								}
								Keys.onReleased: event => {
									if (event.key === Qt.Key_CapsLock)
										root.auth.probeCaps();
								}
							}

							StyledText {
								anchors.fill: parent
								visible: input.text === ""
								horizontalAlignment: Text.AlignHCenter
								text: "Password"
								elide: Text.ElideRight
								color: Theme.foregroundMuted
							}
						}

						Glyph {
							// Caps-lock hint; fades instead of hiding so the text stays centered
							// (same width as the lock icon on the left).
							Layout.preferredWidth: Theme.iconSizeLarge
							opacity: root.auth.capsLock ? 1 : 0
							text: "󰘲"
							font.pixelSize: Theme.fontSizeLarge + 1
							color: Theme.accent
							Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
						}
					}
				}

				// ── Status line ──────────────────────────────────────
				StyledText {
					Layout.fillWidth: true
					Layout.topMargin: Theme.spacingSmall
					horizontalAlignment: Text.AlignHCenter
					wrapMode: Text.Wrap
					font.pixelSize: Theme.fontSizeSmall
					text: {
						if (root.auth.status !== "")
							return root.auth.status;
						if (root.auth.busy)
							return "Checking…";
						if (root.auth.capsLock)
							return "Caps Lock is on";
						return root.hint;
					}
					color: root.auth.statusIsError ? Theme.urgent : (root.auth.capsLock && root.auth.status === "" && !root.auth.busy ? Theme.accent : Theme.foregroundMuted)
				}
			}
		}
	}
}
