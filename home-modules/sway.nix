{
  config,
  pkgs,
  homeLib,
  hostname,
  ...
}:

let
  apodCurrent = "${config.home.homeDirectory}/.local/state/nasa-apod/current";
  swayOutputs = "${config.home.homeDirectory}/.config/sway/outputs";
  lockCommand = pkgs.writeShellScript "sway-lock-apod" ''
    set -euo pipefail

    if [ -e "${apodCurrent}" ]; then
      exec ${pkgs.swaylock}/bin/swaylock -f -i "${apodCurrent}" -s fill --color 000000
    fi

    exec ${pkgs.swaylock}/bin/swaylock -f --color 000000
  '';
  screenshotCommand = pkgs.writeShellScript "sway-screenshot" ''
    set -euo pipefail

    dir="$HOME/Pictures/Screenshots"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    file="$dir/screenshot-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).png"

    if geometry="$(${pkgs.slurp}/bin/slurp)"; then
      ${pkgs.grim}/bin/grim -g "$geometry" "$file"
      ${pkgs.wl-clipboard}/bin/wl-copy < "$file"
    fi
  '';
  cliphistCommand = pkgs.writeShellScript "cliphist-fuzzel" ''
    set -euo pipefail

    ${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel --dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
  '';
  commonStartup = [
    "${homeLib.nasaApodWallpaper}/bin/nasa-apod-wallpaper"
    "${pkgs.waybar}/bin/waybar"
    "${pkgs.mako}/bin/mako"
    "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator"
    "${pkgs.blueman}/bin/blueman-applet"
    "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store"
    "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store"
    "${pkgs.swayidle}/bin/swayidle -w timeout 300 '${lockCommand}' before-sleep '${lockCommand}'"
  ];
  workStartup = [
    "${config.programs.zen-browser.package}/bin/zen-beta"
    "${pkgs.ghostty}/bin/ghostty --fullscreen=true -e ${homeLib.zellijPersistentSession}/bin/zellij-persistent-session"
    "${pkgs.slack}/bin/slack"
    "${homeLib.betterbirdLauncher}/bin/betterbird-profile"
  ];
  personalStartup = [
    "${config.programs.zen-browser.package}/bin/zen-beta"
    "${pkgs.ghostty}/bin/ghostty --fullscreen=true -e ${homeLib.zellijPersistentSession}/bin/zellij-persistent-session"
    "${pkgs.vesktop}/bin/vesktop --start-fullscreen"
    "${homeLib.betterbirdLauncher}/bin/betterbird-profile"
    "${pkgs.signal-desktop}/bin/signal-desktop --start-fullscreen"
    "${pkgs.zulip}/bin/zulip --start-fullscreen"
  ];
  appStartup = if hostname == "framework-work" then workStartup else personalStartup;
in

{
  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;
    wrapperFeatures.gtk = true;
    config = null;
    extraConfig = ''
      set $mod Mod4

      exec ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway SWAYSOCK
      exec ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SWAYSOCK

      default_border none
      default_floating_border none
      hide_edge_borders both
      gaps inner 0
      gaps outer 0
      smart_gaps off
      focus_follows_mouse no
      seat seat0 xcursor_theme Adwaita 28

      input type:touchpad {
        tap enabled
        natural_scroll enabled
        dwt disabled
      }

      include ${swayOutputs}
      output * bg #000000 solid_color

      bindsym $mod+d exec ${pkgs.fuzzel}/bin/fuzzel
      bindsym $mod+p exec ${pkgs.nwg-displays}/bin/nwg-displays
      bindsym $mod+b exec ${pkgs.procps}/bin/pkill -SIGUSR1 waybar
      bindsym $mod+l exec ${lockCommand}
      bindsym $mod+Shift+e exec ${pkgs.sway}/bin/swaymsg exit
      bindsym $mod+Shift+r reload
      bindsym $mod+Shift+q kill
      bindsym $mod+f fullscreen toggle
      bindsym $mod+c exec ${cliphistCommand}
      bindsym Print exec ${screenshotCommand}
      bindsym Sys_Req exec ${screenshotCommand}
      bindsym $mod+Print exec ${screenshotCommand}

      bindsym $mod+h focus left
      bindsym $mod+j focus down
      bindsym $mod+k focus up
      bindsym $mod+Left focus left
      bindsym $mod+Down focus down
      bindsym $mod+Up focus up
      bindsym $mod+Right focus right

      bindsym XF86AudioMute exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindsym XF86AudioLowerVolume exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindsym XF86AudioRaiseVolume exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindsym XF86AudioPlay exec ${pkgs.playerctl}/bin/playerctl play-pause
      bindsym XF86MonBrightnessDown exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%-
      bindsym XF86MonBrightnessUp exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%+

      bindsym $mod+1 workspace number 1
      bindsym $mod+2 workspace number 2
      bindsym $mod+3 workspace number 3
      bindsym $mod+4 workspace number 4
      bindsym $mod+5 workspace number 5
      bindsym $mod+6 workspace number 6
      bindsym $mod+7 workspace number 7
      bindsym $mod+8 workspace number 8
      bindsym $mod+9 workspace number 9
      bindsym $mod+0 workspace number 10

      bindsym $mod+Shift+1 move container to workspace number 1
      bindsym $mod+Shift+2 move container to workspace number 2
      bindsym $mod+Shift+3 move container to workspace number 3
      bindsym $mod+Shift+4 move container to workspace number 4
      bindsym $mod+Shift+5 move container to workspace number 5
      bindsym $mod+Shift+6 move container to workspace number 6
      bindsym $mod+Shift+7 move container to workspace number 7
      bindsym $mod+Shift+8 move container to workspace number 8
      bindsym $mod+Shift+9 move container to workspace number 9
      bindsym $mod+Shift+0 move container to workspace number 10

      for_window [all] fullscreen enable
      for_window [app_id="zen"] move to workspace number 1, fullscreen enable
      for_window [app_id="zen-beta"] move to workspace number 1, fullscreen enable
      for_window [class="zen-beta"] move to workspace number 1, fullscreen enable
      for_window [app_id="com.mitchellh.ghostty"] move to workspace number 2, fullscreen enable
      for_window [class="Slack"] move to workspace number 3, fullscreen enable
      for_window [app_id="slack"] move to workspace number 3, fullscreen enable
      for_window [app_id="Slack"] move to workspace number 3, fullscreen enable
      for_window [app_id="dev.vencord.Vesktop"] move to workspace number 3, fullscreen enable
      for_window [app_id="vesktop"] move to workspace number 3, fullscreen enable
      for_window [class="Betterbird"] move to workspace number 4, fullscreen enable
      for_window [class="eu.betterbird.Betterbird"] move to workspace number 4, fullscreen enable
      for_window [app_id="betterbird"] move to workspace number 4, fullscreen enable
      for_window [app_id="Betterbird"] move to workspace number 4, fullscreen enable
      for_window [class="Signal"] move to workspace number 5, fullscreen enable
      for_window [app_id="signal"] move to workspace number 5, fullscreen enable
      for_window [app_id="signal-desktop"] move to workspace number 5, fullscreen enable
      for_window [class="Zulip"] move to workspace number 6, fullscreen enable
      for_window [app_id="org.zulip.Zulip"] move to workspace number 6, fullscreen enable

      ${pkgs.lib.concatMapStringsSep "\n" (command: "exec ${command}") commonStartup}
      ${pkgs.lib.concatMapStringsSep "\n" (command: "exec ${command}") appStartup}
    '';
  };

  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      mode = "hide";
      start_hidden = true;
      modules-left = [ ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "network"
        "bluetooth"
        "wireplumber"
        "battery"
      ];
      clock = {
        format = "{:%a %b %d  %I:%M %p}";
        tooltip-format = "{:%Y-%m-%d}";
      };
      network = {
        format-wifi = "wifi {essid}";
        format-disconnected = "wifi disconnected";
        tooltip-format-wifi = "{ifname}: {ipaddr}";
      };
      bluetooth = {
        format = "bt on";
        format-disabled = "bt off";
        format-off = "bt off";
        format-connected = "bt {device_alias}";
      };
      wireplumber = {
        format = "vol {volume}%";
        format-muted = "muted";
      };
      battery = {
        format = "bat {capacity}%";
        format-charging = "chg {capacity}%";
        format-plugged = "ac {capacity}%";
        states.warning = 25;
        states.critical = 10;
      };
      tray.spacing = 8;
    };
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "CommitMono Nerd Font", monospace;
        font-size: 12px;
        min-height: 0;
      }

      window#waybar {
        background: #0d1117;
        color: #f0f6fc;
      }

      #clock,
      #tray,
      #network,
      #bluetooth,
      #wireplumber,
      #battery {
        padding: 2px 8px;
      }

      #battery.warning {
        color: #d29922;
      }

      #battery.critical,
      #network.disconnected,
      #wireplumber.muted {
        color: #f85149;
      }
    '';
  };

  services.mako = {
    enable = true;
    settings = {
      background-color = "#0d1117";
      text-color = "#f0f6fc";
      border-color = "#30363d";
      border-radius = 0;
      default-timeout = 5000;
    };
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "CommitMono Nerd Font:size=12";
        terminal = "ghostty";
      };
      colors = {
        background = "0d1117ff";
        text = "f0f6fcff";
        match = "3fb950ff";
        selection = "238636ff";
        selection-text = "ffffffff";
        border = "30363dff";
      };
      border.radius = 0;
    };
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

  home.activation.ensureSwayOutputs = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.config/sway
    if [ ! -e ${swayOutputs} ]; then
      $DRY_RUN_CMD touch ${swayOutputs}
    fi
  '';
}
