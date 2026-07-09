{ ... }:
{
  home = {
    username = "admin";
    homeDirectory = "/home/admin";
    stateVersion = "26.05";
  };
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Derviloper";
        email = "derviloper@gmx.de";
      };
      gpg.format = "ssh";
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };
}
