{ config, pkgs, inputs, ... }:

let
  # antigravityFlake = builtins.getFlake "github:jacopone/antigravity-nix";
  # antigravityPkg = antigravityFlake.packages.${pkgs.system};
  antigravityPkg = inputs.antigravity.packages.${pkgs.system};

  # hyprlandPluginsFlake = builtins.getFlake "github:hyprwm/hyprland-plugins";
  # hyprlandPkg = hyprlandPluginsFlake.inputs.hyprland.packages.${pkgs.system}.hyprland;
  # hyprbarsPkg = hyprlandPluginsFlake.packages.${pkgs.system}.hyprbars;
  # hyprlandPkg = inputs.hyprland.packages.${pkgs.system};

  wallpaper-bin = pkgs.writers.writePython3Bin "wallpaper" {
    libraries = with pkgs.python3Packages; [requests moderngl numpy pillow];
  } (builtins.readFile ./wallpaper/wallpaper.py);
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
  
  # The home.packages option allows you to install Nix packages into your
  # environment.
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    hello
    tree
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
    ]))
    discord
    protontricks
    glab
    (google-chrome.override {
      commandLineArgs = [
	"--force-device-scale-factor=0.8"
      ];
    })
    roboto
    lexend
    direnv
    # basedpyright
    pyright
    godot
    playerctl
    grimblast
    satty
    gemini-cli
    claude-code
    heroic
    # antigravity
    domine
    blender
    kdePackages.qtdeclarative
    kdePackages.qtwayland
    kdePackages.qtsvg
    # papirus-icon-theme
    qt6.qtsvg
    antigravityPkg.default
    antigravityPkg.google-antigravity-ide
    antigravityPkg.google-antigravity-cli
    glslviewer
    vips
    gimp
    unzip
    ffmpegthumbnailer
    ispell
    obs-studio
    libnotify
    openconnect
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
  };
  programs.git = {
    enable = true;
    settings.user = {
      name = "Ben Domine"; 
      email = "ben.w.domine@gmail.com";
    };
  };
  programs.quickshell.enable = true;

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
  };

  # Cursor
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.capitaine-cursors;
    name = "capitaine-cursors";
    size = 36;
  };

  systemd.user.services.wallpaper = {
    Unit = {
      Description = "One-shot wallpaper generator";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${wallpaper-bin}/bin/wallpaper";
    };
  };
  systemd.user.timers.wallpaper = {
    Unit = {
      Description = "Trigger wallpaper generator periodically";
    };
    Timer = {
      OnCalendar = "*:0,15,30,45";
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
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
