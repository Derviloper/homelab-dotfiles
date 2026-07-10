{ pkgs, ... }:
{
  virtualisation.libvirtd.enable = true;

  # virt-install / virt-clone for one-time VM creation; virsh ships with libvirtd.
  environment.systemPackages = [ pkgs.virt-manager ];
}
