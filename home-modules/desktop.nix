{
  config,
  homeLib,
  hostname,
  osConfig ? null,
  pkgs,
  ...
}:

let
  apodSecretEnvironmentFile =
    if
      osConfig != null
      && osConfig ? age
      && osConfig.age ? secrets
      && builtins.hasAttr "nasa-api-env" osConfig.age.secrets
    then
      "-${osConfig.age.secrets."nasa-api-env".path}"
    else
      "-%h/.config/nasa-api.env";
  chatDesktopId = if hostname == "framework-work" then "slack.desktop" else "vesktop.desktop";
  favoriteApps = [
    "zen-beta.desktop"
    "com.mitchellh.ghostty.desktop"
    chatDesktopId
    "betterbird.desktop"
  ]
  ++ (
    if hostname == "framework-work" then
      [ ]
    else
      [
        "signal.desktop"
        "zulip.desktop"
      ]
  );
  autoMoveApplications = [
    "zen-beta.desktop:1"
    "com.mitchellh.ghostty.desktop:2"
    "${chatDesktopId}:3"
    "betterbird.desktop:4"
  ]
  ++ (
    if hostname == "framework-work" then
      [ ]
    else
      [
        "signal.desktop:5"
        "zulip.desktop:6"
      ]
  );
  autostartEntries = [
    "${homeLib.zenStartup}/share/applications/zen-startup.desktop"
    "${homeLib.ghosttyZellijStartup}/share/applications/ghostty-zellij-startup.desktop"
  ]
  ++ (
    if hostname == "framework-work" then
      [
        "${pkgs.slack}/share/applications/slack.desktop"
        "${homeLib.betterbirdStartup}/share/applications/betterbird-startup.desktop"
      ]
    else
      [
        "${homeLib.vesktopStartup}/share/applications/vesktop-startup.desktop"
        "${homeLib.betterbirdStartup}/share/applications/betterbird-startup.desktop"
        "${homeLib.signalStartup}/share/applications/signal-startup.desktop"
        "${homeLib.zulipStartup}/share/applications/zulip-startup.desktop"
      ]
  );
  vlcDesktop = "vlc.desktop";
  vlcVideoMimeTypes = [
    "application/mxf"
    "application/x-extension-mp4"
    "application/x-matroska"
    "application/x-quicktime-media-link"
    "application/x-quicktimeplayer"
    "video/3gp"
    "video/3gpp"
    "video/3gpp2"
    "video/avi"
    "video/divx"
    "video/dv"
    "video/fli"
    "video/flv"
    "video/mp2t"
    "video/mp4"
    "video/mp4v-es"
    "video/mpeg"
    "video/mpeg-system"
    "video/msvideo"
    "video/ogg"
    "video/quicktime"
    "video/vnd.divx"
    "video/vnd.mpegurl"
    "video/vnd.rn-realvideo"
    "video/webm"
    "video/x-anim"
    "video/x-avi"
    "video/x-flc"
    "video/x-fli"
    "video/x-flv"
    "video/x-m4v"
    "video/x-matroska"
    "video/x-mpeg"
    "video/x-mpeg-system"
    "video/x-mpeg2"
    "video/x-ms-asf"
    "video/x-ms-asf-plugin"
    "video/x-ms-asx"
    "video/x-ms-wm"
    "video/x-ms-wmv"
    "video/x-ms-wmx"
    "video/x-ms-wvx"
    "video/x-msvideo"
    "video/x-nsv"
    "video/x-ogm"
    "video/x-ogm+ogg"
    "video/x-theora"
    "video/x-theora+ogg"
    "x-content/video-dvd"
    "x-content/video-svcd"
    "x-content/video-vcd"
  ];
in

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      clock-format = "12h";
      clock-show-weekday = true;
      color-scheme = "prefer-dark";
      cursor-size = 28;
      cursor-theme = "Adwaita";
      document-font-name = "Atkinson Hyperlegible Next 11";
      enable-animations = false;
      enable-hot-corners = false;
      font-name = "Atkinson Hyperlegible Next 11";
      monospace-font-name = "CommitMono Nerd Font 11";
    };
    "org/gnome/system/location" = {
      enabled = true;
    };
    "org/gnome/desktop/media-handling" = {
      automount = true;
      automount-open = false;
      autorun-never = false;
      autorun-x-content-ignore = [ ];
      autorun-x-content-open-folder = [ ];
      autorun-x-content-start-app = [ "x-content/image-dcf" ];
    };
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = [ "<Super>l" ];
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      disable-while-typing = false;
      natural-scroll = true;
      tap-to-click = true;
    };
    "org/gnome/mutter" = {
      center-new-windows = true;
      dynamic-workspaces = false;
      edge-tiling = true;
      workspaces-only-on-primary = true;
    };
    "org/gnome/desktop/wm/preferences" = {
      focus-mode = "click";
      num-workspaces = 6;
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "hidetopbar@mathieu.bidon.ca"
        "wifiqrcode@glerro.pm.me"
        "system-monitor-next@paradoxxx.zero.gmail.com"
        "clipboard-indicator@tudmotu.com"
        "emoji-copy@felipeftn"
        "tailscale@joaophi.github.com"
        "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "gnome-shell-extension-maximized-by-default@stiggimy.github.com"
        "no-titlebar-when-maximized@alec.ninja"
        "reduced-motion-toggle@jetpham.github.com"
      ];
      favorite-apps = favoriteApps;
    };
    "org/gnome/shell/extensions/auto-move-windows" = {
      application-list = autoMoveApplications;
    };
    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      switch-to-workspace-5 = [ "<Super>5" ];
      switch-to-workspace-6 = [ "<Super>6" ];
    };
    "org/gnome/shell/keybindings" = {
      switch-to-application-1 = [ ];
      switch-to-application-2 = [ ];
      switch-to-application-3 = [ ];
      switch-to-application-4 = [ ];
      switch-to-application-5 = [ ];
      switch-to-application-6 = [ ];
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
    };
    "org/gtk/settings/file-chooser" = {
      clock-format = "12h";
      show-hidden = true;
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

  xdg.desktopEntries.betterbird = {
    name = "Betterbird";
    comment = "Mail, RSS and newsgroups client";
    exec = "${homeLib.betterbirdLauncher}/bin/betterbird-profile %u";
    icon = "betterbird";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "Email"
    ];
    mimeType = [
      "x-scheme-handler/mailto"
      "message/rfc822"
      "x-scheme-handler/webcal"
      "x-scheme-handler/webcals"
    ];
    settings = {
      StartupNotify = "false";
      StartupWMClass = "eu.betterbird.Betterbird";
    };
  };

  xdg.autostart = {
    enable = true;
    entries = autostartEntries;
  };

  systemd.user.services.nasa-apod-wallpaper = {
    Unit = {
      Description = "Fetch NASA APOD wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      X-RestartIfChanged = false;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${homeLib.nasaApodWallpaper}/bin/nasa-apod-wallpaper";
      EnvironmentFile = apodSecretEnvironmentFile;
      TimeoutStartSec = "3min";
    };
  };

  systemd.user.timers.nasa-apod-wallpaper = {
    Unit.Description = "Refresh NASA APOD wallpaper regularly";
    Timer = {
      OnActiveSec = "2m";
      OnUnitActiveSec = "1h";
      Persistent = false;
      Unit = "nasa-apod-wallpaper.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.desktopEntries."net.damonlynch.RapidPhotoDownloader" = {
    name = "Rapid Photo Downloader";
    genericName = "Photo Downloader";
    comment = "Download, rename, and back up photos and videos from cameras and cards";
    exec = "rapid-photo-downloader %f";
    icon = "${pkgs.rapid-photo-downloader}/lib/python${pkgs.python3.pythonVersion}/site-packages/raphodo/data/rapid-photo-downloader.svg";
    terminal = false;
    categories = [
      "Graphics"
      "Photography"
    ];
    mimeType = [ "x-content/image-dcf" ];
    settings = {
      StartupWMClass = "rapid-photo-downloader";
      Keywords = "photo;download;photography;import;video;RAW;camera;phone;ingest;backup;memory;card;";
    };
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
      "x-content/image-dcf" = "net.damonlynch.RapidPhotoDownloader.desktop";
      "image/x-canon-cr2" = "gimp.desktop";
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
    }
    // builtins.listToAttrs (
      map (mimeType: {
        name = mimeType;
        value = vlcDesktop;
      }) vlcVideoMimeTypes
    );
  };
}
