#!/usr/bin/env bash
# Calculator: rofi-calc (qalculate). Enter copies the result via wl-copy.
# rofi-calc options are command-line only (not read from config.rasi).
exec rofi -show calc -modes calc \
	-no-show-match -no-sort \
	-automatic-save-to-history \
	-calc-command "echo -n '{result}' | wl-copy" \
	-hint-welcome "Calculator (qalculate) — Enter copies result" \
	-hint-result "󰃬  " \
	-theme "$(dirname "$(readlink -f "$0")")/calc.rasi" \
	"$@"
