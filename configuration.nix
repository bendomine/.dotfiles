# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:
with lib; let
  pkgs-unstable = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  hyprPluginPkgs = inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system};
  hypr-plugin-dir = pkgs.symlinkJoin {
    name = "hyprland-plugins";
    paths = with hyprPluginPkgs; [
      hyprbars
    ];
  };

  # Store copy of quickshell/ for the greetd greeter: the `greeter` user cannot
  # read ~/.dotfiles (home is 0700). The whole directory, because greeter.qml
  # imports Theme.qml, shared/, lock/ and status/ from it. (Flakes only see
  # git-tracked files: new files under quickshell/ need `git add` first.)
  quickshell-config = builtins.path {
    path = ./quickshell;
    name = "quickshell-config";
  };
in {
  imports =
    [ # Include the results of the hardware scan.
      # /etc/nixos/hardware-configuration.nix
      ./hardware-configuration.nix
      inputs.hyprland.nixosModules.default
      ./acer-rgb.nix
      # <home-manager/nixos>
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  # time.timeZone = "America/Los_Angeles";
  services.automatic-timezoned.enable = true;
  services.timesyncd.enable = true;

  services.logind.settings.Login.HandlePowerKey = "ignore";

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
    ];
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Experimental cli
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Hyprland
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
    withUWSM = true;

    # plugins = [
    #   inputs.hyprland-plugins.packages.${pkgs.system}.hyprbars
    # ];
  };
  # nix.settings = {
  #   substituters = ["https://hyprland.cachix.org"];
  #   trusted-public-keys = 
  # }

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    # Required so non-root users are allowed to use the above substituter/keys.
    # Use @wheel for all sudo users, or list your username explicitly.
    trusted-users = ["root" "@wheel"];
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.sessionVariables.HYPR_PLUGIN_DIR = "${hypr-plugin-dir}/lib";
  hardware.graphics = {
    package = pkgs-unstable.mesa;

    enable = true;
    enable32Bit = true;
    package32 = pkgs-unstable.pkgsi686Linux.mesa;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      # pkgs.xdg-desktop-portal-hyprland
    ];
  };
  security.polkit.enable = true;
  # PAM service for the Quickshell lock screen (quickshell/lock/LockScreen.qml,
  # PamContext config "quickshell"): the default unix password auth stack.
  security.pam.services.quickshell = {};

  # Login: greetd on tty1 runs the Quickshell greeter (quickshell/greeter.qml,
  # same look as the lock screen) in the cage kiosk compositor as user
  # `greeter`; after a successful login it starts `start-hyprland` through the
  # user's login shell. Replaces the tty1 agetty login; tty2-6 keep agetty
  # (Ctrl+Alt+F2 if the greeter ever breaks; cage -s allows VT switching).
  #   cage -s  allow VT switching   -d  no client-side decorations
  #        -m last  only the last connected output
  # QT_WAYLAND_DISABLE_WINDOWDECORATION: no Qt title bar on the window.
  # WLR_NO_HARDWARE_CURSORS: software cursor, avoids an invisible cursor on NVIDIA.
  services.greetd = {
    enable = true;
    # Restart greetd if it exits; the default without an initial_session (autologin).
    restart = true;
    settings.default_session.command = concatStringsSep " " [
      "${pkgs.coreutils}/bin/env"
      "QT_WAYLAND_DISABLE_WINDOWDECORATION=1"
      "WLR_NO_HARDWARE_CURSORS=1"
      "${pkgs.cage}/bin/cage -s -d -m last --"
      "${pkgs.quickshell}/bin/quickshell -p ${quickshell-config}/greeter.qml"
    ];
  };
  # The greeter needs a writable home for Quickshell's, fontconfig's and Mesa's
  # caches. Its ~/.cache/wallpaper points at /var/lib/greeter-theme, where
  # wallpaper/wallpaper.py (run as ben) mirrors theme.json and current.jpg, so
  # Theme.qml finds theme.json at the same relative path as in the desktop shell.
  users.users.greeter.home = "/var/lib/greeter";
  systemd.tmpfiles.rules = [
    "d /var/lib/greeter-theme 0755 ben users -"
    "d /var/lib/greeter 0750 greeter greeter -"
    "d /var/lib/greeter/.cache 0750 greeter greeter -"
    "L+ /var/lib/greeter/.cache/wallpaper - - - - /var/lib/greeter-theme"
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # VPN
  services.tailscale.enable = true;

  # Keyboard rgb

  # color-schemes: Breeze schemes the wallpaper script copies into kdeglobals.
  environment.pathsToLink = [ "/share/icons" "/share/color-schemes" ];
  
  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ben = {
    isNormalUser = true;
    description = "Ben Domine";
    extraGroups = [ "networkManager" "wheel" "dialout" "input" ]; # Enable ‘sudo’ for the user.
    initialPassword = "password";
    shell = pkgs.zsh;
  };

  programs.steam.enable = true;
  programs.zsh.enable = true;
  
  # home-manager.useGlobalPkgs = true;
  # home-manager.useUserPackages = true;
  # home-manager.users.ben = import ./home.nix;

  # programs.firefox.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim
    wget
    gcc
    gnumake
    egl-wayland
    pkgs.kitty
    kdePackages.polkit-kde-agent-1
    waybar
    hyprpaper
    mako
    kdePackages.dolphin
    hyprlauncher
    capitaine-cursors
    papirus-icon-theme
    distrobox
    # qt6.qtsvg
  ];
  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    inter
    noto-fonts-color-emoji
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Allow power management
  services.upower.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}

