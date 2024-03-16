{
  # pkgs,
  # inputs,
  ...
}: {
  programs = {
    neovim = {
      enable = true;
    };
  };

  home.username = "jet";
  home.homeDirectory = "/home/jet";
  home.stateVersion = "23.11";
}
