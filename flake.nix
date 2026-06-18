{
  description = "Ben's system config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    nixosConfigurations.bendomine = nixpkgs.lib.nixosSystem {
      modules = [
	./configuration.nix
      ];
    };
  };
}
