{ ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    extraConfig = ''
      PermitEmptyPasswords no
      ClientAliveInterval 300
      ClientAliveCountMax 3
    '';
  };

  services.fail2ban.enable = true;
}
