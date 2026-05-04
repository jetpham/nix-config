{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs.zen-browser.homeModules.default ];

  home.username = "jet";
  home.homeDirectory = "/home/jet";
  home.stateVersion = "25.05";

  home.sessionVariables = {
    BROWSER = "zen";
    TERMINAL = "ghostty";
  };

  xdg.userDirs = {
    enable = true;
    setSessionVariables = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4 = {
      theme = config.gtk.theme;
      extraConfig.gtk-application-prefer-dark-theme = 1;
    };
  };
}
