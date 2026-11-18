{ pkgs, ... }:
{
  systemd.user.services.yacreader-library = {
    Unit.Description = "YACReader library and reading progress server";
    Service = {
      ExecStart = "${pkgs.yacreader}/bin/YACReaderLibraryServer start --port 8080";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.services.yacreader-library-update = {
    Unit.Description = "Import completed manga into the shared YACReader library";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.yacreader}/bin/YACReaderLibraryServer update-library %h/Documents/Comics";
      TimeoutStartSec = "15min";
      UMask = "0077";
    };
  };
  systemd.user.timers.yacreader-library-update = {
    Unit.Description = "Refresh the shared manga library after downloads finish";
    Timer = {
      OnStartupSec = "30s";
      OnUnitInactiveSec = "2min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
  # An explicit user launcher is noticed immediately by the running GNOME session.
  xdg.desktopEntries."org.jellyfin.JellyfinDesktop" = {
    name = "Jellyfin Desktop";
    genericName = "Media Library";
    comment = "Watch the Framework Jellyfin library";
    exec = "${pkgs.jellyfin-desktop}/bin/jellyfin-desktop --desktop --windowed";
    icon = "org.jellyfin.JellyfinDesktop";
    terminal = false;
    startupNotify = true;
    settings.StartupWMClass = "org.jellyfin.JellyfinDesktop";
    categories = [
      "AudioVideo"
      "Video"
      "Player"
      "TV"
    ];
    settings.Keywords = "Jellyfin;Movies;TV;Anime;Media;";
  };
}
