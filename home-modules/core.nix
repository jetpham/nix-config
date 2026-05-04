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
    BROWSER = "${pkgs.xdg-utils}/bin/xdg-open";
    GH_BROWSER = "${pkgs.xdg-utils}/bin/xdg-open";
    GIT_BROWSER = "${pkgs.xdg-utils}/bin/xdg-open";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    TERMINAL = "ghostty";
    XCURSOR_SIZE = "28";
    XCURSOR_THEME = "Adwaita";
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

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 28;
  };
}
