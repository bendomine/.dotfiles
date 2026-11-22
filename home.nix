{ config, pkgs, inputs, ... }:

let
  # antigravityFlake = builtins.getFlake "github:jacopone/antigravity-nix";
  # antigravityPkg = antigravityFlake.packages.${pkgs.system};
  # antigravityPkg = inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system};

  # hyprlandPluginsFlake = builtins.getFlake "github:hyprwm/hyprland-plugins";
  # hyprlandPkg = hyprlandPluginsFlake.inputs.hyprland.packages.${pkgs.system}.hyprland;
  # hyprbarsPkg = hyprlandPluginsFlake.packages.${pkgs.system}.hyprbars;
  # hyprlandPkg = inputs.hyprland.packages.${pkgs.system};

  wallpaper-bin = pkgs.writers.writePython3Bin "wallpaper" {
    libraries = with pkgs.python3Packages; [moderngl numpy pillow];
  } (builtins.readFile ./wallpaper/wallpaper.py);

  # One-shot wallpaper unit running `wallpaper<args>`.
  wallpaperService = args: {
    Unit = {
      Description = "One-shot wallpaper generator";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${wallpaper-bin}/bin/wallpaper${args}";
      Environment = [
        # Out-of-store shader: edits apply without a rebuild.
        "WALLPAPER_SHADER=%h/.dotfiles/wallpaper/main.frag"
        # hyprctl/makoctl come from the system and user profiles.
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin"
      ];
    };
  };

  # Flake inputs whose packages should track upstream; `nup` bumps exactly these.
  flakePackages = [ "omp" ];
  rebuild = "sudo nixos-rebuild switch --flake \"$HOME/.dotfiles#$(hostname)\"";
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "ben";
  home.homeDirectory = "/home/ben";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.11"; # Please read the comment before changing.

  fonts.fontconfig.enable = true;

  imports = [ inputs.omp.homeManagerModules.default ];
  
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    hello
    tree
    aalib
    # hyprlandPkg
    # hyprbarsPkg
    fd
    feh
    fastfetch
    spotify
    gh
    (python313.withPackages (ps: with ps; [
      requests
      moderngl
      numpy
      pillow
      matplotlib # also renders the quickshell calculator's LaTeX preview
    ]))
    discord
    protontricks
    glab
    roboto
    lexend
    direnv
    pyright
    godot
    playerctl
    grimblast
    satty
    claude-code
    heroic
    (google-fonts.override { fonts = [ "Domine" ]; } )
    blender
    kdePackages.qtdeclarative
    kdePackages.qtwayland
    kdePackages.qtsvg
    # BreezeLight/BreezeDark color schemes: the wallpaper script copies the
    # one matching the theme's light/dark mode into kdeglobals for Qt apps.
    kdePackages.breeze
    # Adwaita-dark for GTK3 apps (GTK3 only ships Adwaita built in); the
    # wallpaper script switches gtk-theme between Adwaita and Adwaita-dark.
    gnome-themes-extra
    qt6.qtsvg
    glslviewer
    vips
    gimp
    unzip
    ffmpegthumbnailer
    ispell
    obs-studio
    libnotify
    openconnect
    kitty.terminfo
    btop
    (texliveBasic.withPackages (
      ps: with ps; [
	dvisvgm dvipng
	wrapfig amsmath ulem hyperref capt-of
	physics ec cm-super xcolor
      ]
    ))
    rofi
    libqalculate
    wl-clipboard
    brightnessctl
    qalculate-qt
    audacious
    cmake
    libtool
    kdePackages.okular
    pandoc
    clang-tools
    zellij
    (brave.override {
      commandLineArgs = [
	"--force-device-scale-factor=0.8"
      ];
    })
    R
    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];
  programs.emacs.enable = true;
  services.emacs = {
    enable = true;
    client.enable = true;
    startWithUserSession = "graphical";
  };
  # Idle lock + screen blanking. Settings live out of store in hypr/hypridle.conf
  # (~/.config/hypr is linked to the repo, so HM must not write a file there);
  # it locks through the Quickshell lock screen (`qs ipc call lock lock`).
  # Started by graphical-session.target, which UWSM reaches with WAYLAND_DISPLAY,
  # HYPRLAND_INSTANCE_SIGNATURE and PATH imported into the user manager.
  services.hypridle.enable = true;
  programs.git = {
    enable = true;
    settings.user = {
      name = "Ben Domine"; 
      email = "ben.w.domine@gmail.com";
    };
  };
  programs.zsh = {
    enable = true;  
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    initContent = ''
      # The Linux virtual console (tty1 before Hyprland, Ctrl+Alt+F2...) has no
      # Nerd Font glyphs and only 8/16 colours: use the ASCII-only prompt there.
      # Starship reads STARSHIP_CONFIG on every render, so order vs. its init is moot.
      # The elif drops the variable when it was inherited from a tty session
      # (e.g. Hyprland launched from tty1 -> kitty), keeping GUI prompts intact.
      if [[ $TERM == linux ]]; then
        export STARSHIP_CONFIG="$HOME/.config/starship-tty.toml"
      elif [[ $STARSHIP_CONFIG == */starship-tty.toml ]]; then
        unset STARSHIP_CONFIG
      fi
      echo
      fastfetch
      if [[ -n "$KITTY_INSTALLATION_DIR" ]]; then
  export KITTY_SHELL_INTEGRATION="enabled"
  source "$KITTY_INSTALLATION_DIR/shell-integration/zsh/kitty-integration"
  fi

export EDITOR="emacsclient -c"
setopt aliases
    '';

    shellAliases = {
      # Rebuild from the current lock; nothing is updated.
      nrs = rebuild;
      # Bump the flake-provided packages to upstream HEAD, then rebuild.
      nup = "nix flake update ${builtins.concatStringsSep " " flakePackages} --flake \"$HOME/.dotfiles\" && ${rebuild}";
    };
  };
  programs.quickshell.enable = true;
  programs.starship.enable = true;

  programs.omp = {
    enable = true;
    # The module overwrites ~/.omp/agent/config.yml with exactly these settings
    # on every switch, so anything chosen in omp at runtime (onboarding,
    # /settings) is lost. Declare it here instead. setupVersion marks the setup
    # wizard as done; bump it when an omp update shows the wizard again
    # (CURRENT_SETUP_VERSION in packages/tui/src/setup/setup-version.ts).
    settings = {
      setupVersion = 3;
      startup.quiet = true;
      symbolPreset = "nerd";
      composer.shape = "band";
      theme = {
        dark = "titanium";
        light = "light";
      };
    };
  };

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  # I’ll mkOutOfStoreSymlink files, so that I can update config files without
  # home-manager switching all the time.
  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    dotfilesDir = "${config.home.homeDirectory}/.dotfiles";
  in {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
    ".emacs.d".source = link "${dotfilesDir}/emacs";
    ".bashrc".source = link "${dotfilesDir}/bashrc";
  };
  xdg.configFile = let
    link = config.lib.file.mkOutOfStoreSymlink;
    dotfilesDir = "${config.home.homeDirectory}/.dotfiles";
  in {
    "waybar".source = link "${dotfilesDir}/waybar";
    "mako".source = link "${dotfilesDir}/mako";
    "kitty".source = link "${dotfilesDir}/kitty";
    "hypr".source = link "${dotfilesDir}/hypr";
    "quickshell".source = link "${dotfilesDir}/quickshell";
    "rofi".source = link "${dotfilesDir}/rofi";
    "btop".source = link "${dotfilesDir}/btop";
    "gtk-3.0".source = link "${dotfilesDir}/gtk-3.0";
    "starship.toml".source = link "${dotfilesDir}/starship.toml";
    "starship-tty.toml".source = link "${dotfilesDir}/starship-tty.toml";
  };

  # Cursor
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.capitaine-cursors;
    name = "capitaine-cursors";
    size = 24;
  };

  # wallpaper.service picks a random light/dark theme; the template instance
  # wallpaper@light.service / wallpaper@dark.service forces the mode.
  systemd.user.services.wallpaper = wallpaperService "";
  systemd.user.services."wallpaper@" = wallpaperService " --mode %i";
  # mako refuses to start when its include file is missing.
  systemd.user.tmpfiles.rules = [
    "d %h/.cache/wallpaper 0755 - - -"
    "f %h/.cache/wallpaper/mako-colors 0644 - - -"
    "f %h/.cache/wallpaper/kitty-colors.conf 0644 - - -"
  ];
  systemd.user.timers.wallpaper = {
    Unit = {
      Description = "Trigger wallpaper generator periodically";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Default applications
  xdg = {
    enable = true;

    desktopEntries.emacsclient-custom = {
      name = "Emacs Daemon Client";
      exec = "emacsclient -n -a \"\" %F";
      terminal = false;
      categories = [ "Utility" "TextEditor" ];
      mimeType = [ "text/plain" "text/markdown" ];
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
	"text/plain" = [ "emacsclient-custom.desktop" ];
	"text/markdown" = [ "emacsclient-custom.desktop" ];
	"application/pdf" = [ "org.kde.okular.desktop" ];
      };
    };
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/ben/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "emacs -c";
    XDG_DATA_DIRS = "$XDG_DATA_DIRS:$HOME/.nix-profile/share:/run/current-system/sw/share";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "24";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
