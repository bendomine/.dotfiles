{
  description = "Ben's system config flake";

  inputs = {
    # Rolling package set: moves whenever you `nix flake update nixpkgs`.
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # Frozen package set: an exact commit, so even a bare `nix flake update`
    # never moves it. Exposed as `pkgs.pinned.<name>`. Bump by editing the rev.
    nixpkgs-pinned.url = "github:nixos/nixpkgs/31ecbaca1bdefa45dffc409f0250bd8039ea0010";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    omp = {
      url = "github:can1357/oh-my-pi";
      # Build with the system's nixpkgs instead of downloading omp's own toolchain each bump.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ...}@inputs: {

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
	{
	  nixpkgs.overlays = [
	    (final: prev: {
	      pinned = import inputs.nixpkgs-pinned {
	        inherit (prev.stdenv.hostPlatform) system;
	        inherit (prev) config;
	      };
	    })
	  ];
	}
	./configuration.nix

	home-manager.nixosModules.home-manager
	{
	  home-manager.useGlobalPkgs = true;
	  home-manager.useUserPackages = true;
	  home-manager.extraSpecialArgs = { inherit inputs; };
	  home-manager.users.ben = import ./home.nix;
	}
      ];
    };
  };
}
