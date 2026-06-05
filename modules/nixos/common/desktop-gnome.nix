{ pkgs, ... }:

{
  services.flatpak.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome.sushi.enable = true;

  environment.gnome.excludePackages = with pkgs; [
    decibels
    epiphany
    evince
    geary
    gnome-calculator
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-connections
    gnome-console
    gnome-contacts
    gnome-font-viewer
    gnome-logs
    gnome-maps
    gnome-music
    gnome-tour
    gnome-weather
    papers
    showtime
    simple-scan
    snapshot
    totem
    yelp
  ];

  services.accounts-daemon.enable = true;
  programs.dconf.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  security.polkit.enable = true;
  programs.gphoto2.enable = true;

  services.printing.enable = true;

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };
}
