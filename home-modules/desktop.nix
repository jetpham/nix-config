{
  pkgs,
  homeLib,
  hostname,
  ...
}:

let
  autostartEntries =
    if hostname == "framework-work" then
      [
        "${homeLib.zenStartup}/share/applications/zen-startup.desktop"
        "${homeLib.ghosttyZellijStartup}/share/applications/ghostty-zellij-startup.desktop"
        "${pkgs.slack}/share/applications/slack.desktop"
        "${homeLib.betterbird}/share/applications/betterbird.desktop"
      ]
    else
      [
        "${homeLib.zenStartup}/share/applications/zen-startup.desktop"
        "${homeLib.ghosttyZellijStartup}/share/applications/ghostty-zellij-startup.desktop"
        "${homeLib.signalStartup}/share/applications/signal-startup.desktop"
        "${pkgs.slack}/share/applications/slack.desktop"
        "${homeLib.betterbird}/share/applications/betterbird.desktop"
        "${homeLib.vesktopStartup}/share/applications/vesktop-startup.desktop"
        "${homeLib.zulipStartup}/share/applications/zulip-startup.desktop"
      ];
in

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      clock-format = "12h";
      clock-show-weekday = true;
      color-scheme = "prefer-dark";
      enable-animations = false;
      enable-hot-corners = false;
    };
    "org/gnome/system/location" = {
      enabled = true;
    };
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
    };
    "org/gtk/settings/file-chooser" = {
      clock-format = "12h";
      show-hidden = true;
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      disable-while-typing = false;
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "hidetopbar@mathieu.bidon.ca"
        "wifiqrcode@glerro.pm.me"
        "system-monitor@paradoxxx.zero.gmail.com"
        "clipboard-indicator@tudmotu.com"
        "emoji-copy@felipeftn"
        "tailscale-gnome-qs@tailscale-qs.github.io"
      ];
    };
  };

  xdg.desktopEntries.extract-here = {
    name = "Extract Here";
    exec = "file-roller --extract-here %U";
    icon = "file-roller";
    type = "Application";
    categories = [ "Utility" ];
    mimeType = [
      "application/zip"
      "application/x-tar"
      "application/x-compressed-tar"
      "application/x-bzip-compressed-tar"
      "application/x-xz-compressed-tar"
      "application/x-zstd-compressed-tar"
      "application/gzip"
      "application/x-7z-compressed"
      "application/x-rar"
      "application/x-rar-compressed"
    ];
    noDisplay = true;
  };

  xdg.autostart = {
    enable = true;
    entries = autostartEntries;
  };

  home.file.".local/share/gnome-shell/extensions/tailscale-gnome-qs@tailscale-qs.github.io" = {
    source = "${homeLib.tailscaleQsExtension}/share/gnome-shell/extensions/tailscale-gnome-qs@tailscale-qs.github.io";
    recursive = true;
  };

  systemd.user.services.nasa-apod-wallpaper = {
    Unit = {
      Description = "Fetch NASA APOD wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${homeLib.nasaApodWallpaper}/bin/nasa-apod-wallpaper";
    };
  };

  systemd.user.timers.nasa-apod-wallpaper = {
    Unit.Description = "Refresh NASA APOD wallpaper regularly";
    Timer = {
      OnStartupSec = "2m";
      OnCalendar = "hourly";
      Persistent = true;
      Unit = "nasa-apod-wallpaper.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
      "x-scheme-handler/mailto" = "betterbird.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-bzip-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-zstd-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/gzip" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/x-rar" = "org.gnome.FileRoller.desktop";
      "application/x-rar-compressed" = "org.gnome.FileRoller.desktop";
    };
  };
}
