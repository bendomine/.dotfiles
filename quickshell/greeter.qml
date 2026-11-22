import Quickshell
import "./greeter"

// Login greeter entry point (not part of the desktop shell, which starts from
// shell.qml): configuration.nix has greetd run
//   cage -s -d -m last -- quickshell -p <store copy of this folder>/greeter.qml
// It sits at the config root rather than in greeter/ because Quickshell
// blackholes imports outside the entry file's folder, and the greeter shares
// Theme.qml, shared/, lock/ and status/ with the shell.
// Preview inside a normal session: `qs -p ~/.config/quickshell/greeter.qml`
// (logging in then fails with "greetd is not running").
ShellRoot {
	Greeter {}
}
