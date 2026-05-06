{ config, pkgs, ... }:

let
  greetdApodDir = "/var/lib/greetd/apod";
  greetdApodCurrent = "${greetdApodDir}/current";
  fetchGreetdApod = pkgs.writeShellApplication {
    name = "greetd-apod-wallpaper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      state_dir="${greetdApodDir}"
      current_link="${greetdApodCurrent}"
      user_current="/home/jet/.local/state/nasa-apod/current"
      mkdir -p "$state_dir"
      chmod 0755 "$state_dir"

      install_current() {
        local source="$1"
        local target="$2"

        if [ -s "$source" ]; then
          cp --dereference --force "$source" "$target"
          chmod 0644 "$target"
          ln -sfn "$target" "$current_link"
        fi
      }

      if [ ! -e "$current_link" ] && [ -e "$user_current" ]; then
        install_current "$user_current" "$state_dir/bootstrap"
      fi

      curl_args=(
        --fail
        --silent
        --show-error
        --location
        --retry 30
        --retry-all-errors
        --retry-delay 2
        --connect-timeout 10
        --max-time 300
      )

      json="$(curl "''${curl_args[@]}" 'https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY' || true)"
      if [ -z "$json" ]; then
        exit 0
      fi

      media_type="$(printf '%s' "$json" | jq -r '.media_type // empty')"
      if [ "$media_type" != "image" ]; then
        exit 0
      fi

      image_url="$(printf '%s' "$json" | jq -r '.hdurl // .url // empty')"
      if [ -z "$image_url" ]; then
        exit 0
      fi

      ext="''${image_url##*.}"
      ext="''${ext%%\?*}"
      case "$ext" in
        jpg|jpeg|png|webp) ;;
        *) ext="jpg" ;;
      esac

      date_stamp="$(printf '%s' "$json" | jq -r '.date // empty')"
      if [ -z "$date_stamp" ]; then
        date_stamp="$(date +%F)"
      fi

      target="$state_dir/apod-$date_stamp.$ext"
      tmp="$target.tmp"

      if [ ! -s "$target" ]; then
        if curl "''${curl_args[@]}" "$image_url" -o "$tmp" && [ -s "$tmp" ]; then
          mv "$tmp" "$target"
          chmod 0644 "$target"
        else
          rm -f "$tmp"
        fi
      fi

      if [ -e "$target" ]; then
        ln -sfn "$target" "$current_link"
      fi
    '';
  };
in

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Ensure current wireless firmware is available.
  hardware.enableRedistributableFirmware = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true; # Show battery charge of Bluetooth devices
      };
    };
  };
  services.blueman.enable = true;

  networking.networkmanager.enable = true;
  networking.networkmanager.settings = {
    connection = {
      "wifi.powersave" = 2;
    };
    device = {
      "wifi.scan-rand-mac-address" = false;
    };
  };

  services.resolved.enable = true;

  networking.firewall.enable = true;
  # Required for Tailscale
  networking.firewall.checkReversePath = "loose";
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 4096 ];

  services.tailscale = {
    enable = true;
  };

  systemd.services.tailscale-set-operator = {
    description = "Set Tailscale operator user";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.tailscale ];
    script = ''
      tailscale set --operator=jet
    '';
  };

  systemd.services.opencode-tailnet = {
    description = "Expose OpenCode on the tailnet";
    after = [
      "network-online.target"
      "tailscaled.service"
      "tailscale-set-operator.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "tailscaled.service"
      "tailscale-set-operator.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "jet";
      Restart = "always";
      RestartSec = 5;
      ExecStartPre = [
        "${pkgs.tailscale}/bin/tailscale serve --bg 4096"
      ];
      ExecStart = "/etc/profiles/per-user/jet/bin/opencode serve --hostname 127.0.0.1 --port 4096";
      WorkingDirectory = config.users.users.jet.home;
    };
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # Framework Laptop 13 AMD AI 300 Series specific configurations
  # Enable AMD GPU support and power management
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Enable keyd for key remapping
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ]; # Apply to all keyboards
        settings = {
          main = {
            capslock = "esc";
            esc = "capslock";
            leftalt = "leftcontrol";
            leftcontrol = "leftalt";
            mute = "mute"; # ← Key 1: mute
            volumedown = "playpause"; # ← Key 2: play/pause
            volumeup = "volumedown"; # ← Key 3: vol down
            previoussong = "volumeup"; # ← Key 4: vol up
            playpause = "command(touch /tmp/keyd-f5-test)"; # ← Key 5: lock screen (testing)
            nextsong = "noop"; # ← Key 6: disabled
            brightnessdown = "noop"; # ← Key 7: disabled
            brightnessup = "noop"; # ← Key 8: disabled
            # Key 9: display toggle (leftmeta+p) - disabled below
            rfkill = "brightnessdown"; # ← Key 10: brightness down
            sysrq = "brightnessup"; # ← Key 11: brightness up
            media = "sysrq"; # ← Key 12: screenshot
          };
        };
      };
      frameworkRadio = {
        ids = [ "32ac:0006" ];
        settings = {
          main = {
            brightnessdown = "noop"; # ← Key 7: disabled
            brightnessup = "noop"; # ← Key 8: disabled
            rfkill = "brightnessdown"; # ← Key 10: brightness down
          };
        };
      };
    };
  };

  # Prevent trackpad interference with keyd
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Serial Keyboards]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';

  # Codex currently probes the conventional FHS bubblewrap path.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/bwrap - - - - ${pkgs.bubblewrap}/bin/bwrap"
    "d ${greetdApodDir} 0755 root root -"
  ];

  # Set Ghostty as default terminal
  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [ "com.mitchellh.ghostty.desktop" ];
    };
  };

  services.flatpak.enable = true;

  virtualisation.docker.enable = true;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "env GTK_USE_PORTAL=0 GDK_DEBUG=no-portals XDG_DATA_DIRS=/run/current-system/sw/share ${pkgs.dbus}/bin/dbus-run-session ${pkgs.cage}/bin/cage -s -d -- ${config.programs.regreet.package}/bin/regreet";
      user = "greeter";
    };
  };

  programs.regreet = {
    enable = true;
    font = {
      package = pkgs.nerd-fonts.commit-mono;
      name = "CommitMono Nerd Font";
      size = 16;
    };
    settings = {
      background = {
        path = greetdApodCurrent;
        fit = "Cover";
      };
      GTK.application_prefer_dark_theme = true;
      appearance.greeting_msg = "Welcome back";
      widget.clock = {
        format = "%a %b %d  %I:%M %p";
        resolution = "1s";
      };
    };
  };

  services.accounts-daemon.enable = true;

  systemd.services.greetd-apod-wallpaper = {
    description = "Fetch NASA APOD wallpaper for greetd";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fetchGreetdApod}/bin/greetd-apod-wallpaper";
    };
  };

  systemd.timers.greetd-apod-wallpaper = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnCalendar = "hourly";
      Persistent = true;
      Unit = "greetd-apod-wallpaper.service";
    };
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    config.common.default = [
      "wlr"
      "gtk"
    ];
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };

  programs.dconf.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  security.polkit.enable = true;
  security.pam.services.swaylock = { };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  users.users.jet = {
    isNormalUser = true;
    description = "Jet";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "render"
      "docker"
    ];
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "jet"
    ];
    max-jobs = "auto";
    cores = 0;
    build-users-group = "nixbld";
  };
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;

  # Framework-specific services
  # Enable fwupd for BIOS updates (distributed through LVFS)
  services.fwupd.enable = true;

  # Enable periodic TRIM for NVMe/SSD health
  services.fstrim.enable = true;
  services.irqbalance.enable = true;
  services.earlyoom.enable = true;

  # Power management for laptop
  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
        HandlePowerKey = "suspend";
      };
    };
  };

  # Enable auto-cpufreq for intelligent power management (replaces TLP)
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };

  # Disable power-profiles-daemon (conflicts with auto-cpufreq)
  services.power-profiles-daemon.enable = false;

  # Enable power management (governor managed dynamically by auto-cpufreq)
  powerManagement.enable = true;

  # v4l2loopback for OBS Virtual Camera
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  # RAM optimizations for 96GB system
  boot.kernel.sysctl = {
    "vm.vfs_cache_pressure" = 50; # Keep more filesystem cache in RAM
    "vm.dirty_ratio" = 15; # Write to disk when 15% of RAM is dirty
    "vm.dirty_background_ratio" = 5; # Start writing when 5% dirty
    "kernel.nmi_watchdog" = 0;
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  environment.systemPackages = with pkgs; [
    bubblewrap
    docker
    docker-compose
    flatpak
    wget
    nh
  ];

  programs.steam.enable = true;
  programs.nix-index-database.comma.enable = true;

  # https://wiki.nixos.org/wiki/Appimage
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # GameCube adapter udev rules for Slippi/Dolphin
  # Disable USB autosuspend for Framework's problematic devices (fingerprint reader, USB-C hub)
  services.udev.extraRules = ''
    # GameCube adapter USB device (vendor ID 057e, product ID 0337)
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
    # GameCube adapter HID device (needed for Dolphin to access controllers)
    KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666", GROUP="input"
    # Disable autosuspend for Framework fingerprint reader
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="27a6", ATTR{power/autosuspend}="-1"
    # Disable autosuspend for Framework USB-C hub controllers
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="32ac", ATTR{power/autosuspend}="-1"
  '';

  system.stateVersion = "25.05";

}
