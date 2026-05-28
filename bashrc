echo
# .fastfetch-wrapped -c examples/30
.fastfetch-wrapped -c examples/6

# Get the current terminal width in columns
# TERMINAL_WIDTH=$(tput cols)

# Set your threshold (e.g., 90 columns)
# if [ "$TERMINAL_WIDTH" -ge 90 ]; then
#     # Large window: run normal fastfetch
#     fastfetch -c neofetch
# else
#     # Small window or split: run a compact version
#     fastfetch --logo-type small
# fi
if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
    export KITTY_SHELL_INTEGRATION="enabled"
    source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
fi

alias hms="home-manager switch -f ~/.dotfiles/home.nix"