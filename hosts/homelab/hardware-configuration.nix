# Placeholder hardware configuration.
#
# This file is REGENERATED on the target during install. Run:
#
#   nixos-anywhere ... --generate-hardware-config \
#     nixos-generate-config ./hosts/homelab/hardware-configuration.nix ...
#
# (or `nixos-generate-config --show-hardware-config` on the booted machine),
# then commit the result. It captures the real kernel modules, CPU
# microcode, and any host-specific hardware quirks. Filesystems come from
# ./disko.nix, so they are intentionally not declared here.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
