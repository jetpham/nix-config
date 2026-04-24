{ config, inputs, ... }:

{
  imports = [ inputs.zen-browser.homeModules.default ];

  home.username = "jet";
  home.homeDirectory = "/home/jet";
  home.stateVersion = "25.05";

  home.sessionVariables = {
    BROWSER = "zen";
    TERMINAL = "kitty";
  };

  xdg.userDirs = {
    enable = true;
    setSessionVariables = true;
  };

  gtk = {
    enable = true;
    gtk4.theme = config.gtk.theme;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
  };
}
