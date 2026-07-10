{ ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.admin = import ../home/admin;
  };

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILBm+ebJElO2PL4BqWgb/wdM+QZPYshQRDTSwnBGYobz"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
