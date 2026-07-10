{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "homelab";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.admin = import ../../home/admin;
  };

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILBm+ebJElO2PL4BqWgb/wdM+QZPYshQRDTSwnBGYobz"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
    };
    extraConfig = ''
      PermitEmptyPasswords no
      ClientAliveInterval 300
      ClientAliveCountMax 3
    '';
  };

  services.fail2ban.enable = true;

  networking.firewall = {
    allowedTCPPorts = [ 22 ];
  };

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    optimise.automatic = true;
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    btop
    fzf
    zsh
    zsh-powerlevel10k
    ghostty.terminfo
  ];

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    interactiveShellInit = ''
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi
      source /etc/p10k.zsh
    '';
  };

  environment.etc."p10k.zsh".source = ./p10k.zsh;

  users.defaultUserShell = pkgs.zsh;

  home-manager.sharedModules = [ { home.file.".zshrc".text = ""; } ];

  system.stateVersion = "26.05";
}
