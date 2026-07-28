{ config, lib, pkgs, ... }:
let
  # Define the custom kernel module derivation
  acer-rgb-module = pkgs.stdenv.mkDerivation {
    pname = "acer-predator-rgb-module";
    version = "git";

    src = pkgs.fetchFromGitHub {
      owner = "JafarAkhondali";
      repo = "acer-predator-turbo-and-rgb-keyboard-linux-module";
      # It's best practice to pin a specific commit hash here eventually, 
      # but 'master' works to grab the latest version.
      rev = "master"; 
      hash = "sha256-TGBo9GxVJ74mOnqpkjZRFk0e7XiT6iZbVyMeDmRXLyk="; 
    };

    # Pull in the headers and build tools for your current kernel
    nativeBuildInputs = config.boot.kernelPackages.kernel.moduleBuildDependencies;

    buildPhase = ''
      make -C ${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build M=$(pwd) modules
    '';

    installPhase = ''
      make -C ${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build M=$(pwd) INSTALL_MOD_PATH=$out modules_install
    '';
  };
in
{
  boot.extraModulePackages = [ acer-rgb-module ];
  boot.kernelModules = [ "facer" ];
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "acer-rgb" ''
      sudo ${pkgs.python3}/bin/python ${acer-rgb-module.src}/facer_rgb.py "$@"
    '')
  ];
}