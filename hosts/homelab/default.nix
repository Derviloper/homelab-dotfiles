{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/nix.nix
    ../../modules/ssh.nix
    ../../modules/networking.nix
    ../../modules/users.nix
    ../../modules/shell.nix
    ../../modules/locale.nix
  ];

  networking.hostName = "homelab";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  system.stateVersion = "26.05";
}
