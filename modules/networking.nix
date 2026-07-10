{ ... }:
{
  # Turn the physical NIC into a bridge port so VMs can attach directly to the
  # LAN. The host's IP moves from enp2s0 onto br0 (DHCP). enp1s0 is unused.
  networking.useDHCP = false;
  networking.bridges.br0.interfaces = [ "enp2s0" ];
  networking.interfaces.br0.useDHCP = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 22 ];
  };
}
