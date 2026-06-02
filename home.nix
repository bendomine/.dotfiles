{ config, pkgs, ... }:

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
    fd
    fastfetch
    spotify
    gh
    python313
    discord
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
    domine
    blender
    kdePackages.qtdeclarative
    kdePackages.qtwayland
    kdePackages.qtsvg
    # papirus-icon-theme
    qt6.qtsvg
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
