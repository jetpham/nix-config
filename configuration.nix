{ config, pkgs, ... }:

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
        MultiProfile = "multiple";
      };
    };
  };
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
    description = "Set Tailscale local preferences";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    path = [ pkgs.tailscale ];
    script = ''
      tailscale set --operator=jet
      tailscale set --exit-node-allow-lan-access=true
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
    path = [
      pkgs.tailscale
      pkgs.coreutils
      pkgs.gnugrep
    ];
    preStart = ''
      for attempt in {1..60}; do
        if tailscale status --json --peers=false | grep -q '"BackendState": *"Running"'; then
          tailscale serve --bg 4096
          exit 0
        fi

        sleep 1
      done

      echo "Timed out waiting for Tailscale to reach Running state"
      exit 1
    '';
    serviceConfig = {
      Type = "simple";
      User = "jet";
      Restart = "always";
      RestartSec = 5;
      TimeoutStartSec = 75;
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

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome.sushi.enable = true;

  # Keep GNOME's shell and file-manager integration while dropping apps replaced elsewhere.
  environment.gnome.excludePackages = with pkgs; [
    baobab
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
    gnome-system-monitor
    gnome-text-editor
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

  age = {
    identityPaths = [ "/home/jet/.ssh/id_ed25519" ];
    secrets.nasa-api-env = {
      file = ./secrets/nasa-api.env.age;
      owner = "jet";
      group = "users";
      mode = "0400";
    };
  };

  fonts = {
    packages = [
      pkgs.atkinson-hyperlegible-next
      pkgs.nerd-fonts.commit-mono
      pkgs.nerd-fonts.symbols-only
      pkgs.noto-fonts
      pkgs.noto-fonts-cjk-sans
      pkgs.noto-fonts-cjk-serif
      pkgs.noto-fonts-color-emoji
      pkgs.symbola
      pkgs.unifont
      pkgs.unifont_upper
    ];

    fontconfig = {
      allowBitmaps = false;
      useEmbeddedBitmaps = false;

      defaultFonts = {
        sansSerif = [
          "Atkinson Hyperlegible Next"
          "Noto Sans"
          "Noto Sans CJK JP"
          "Noto Sans CJK SC"
          "Noto Sans CJK TC"
          "Noto Sans CJK HK"
          "Noto Sans CJK KR"
          "Symbols Nerd Font"
          "Noto Color Emoji"
          "Symbola"
          "Unifont"
        ];
        serif = [
          "Noto Serif"
          "Noto Serif CJK JP"
          "Noto Serif CJK SC"
          "Noto Serif CJK TC"
          "Noto Serif CJK KR"
          "Noto Color Emoji"
          "Symbola"
          "Unifont"
        ];
        monospace = [
          "CommitMono Nerd Font"
          "Noto Sans Mono"
          "Noto Sans Mono CJK JP"
          "Symbols Nerd Font Mono"
          "Noto Color Emoji"
          "Unifont"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  programs.dconf.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  security.polkit.enable = true;
  programs.gphoto2.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.printing.enable = true;

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.extraConfig."10-bluez" = {
      "monitor.bluez.properties" = {
        "bluez5.roles" = [
          "a2dp_sink"
          "a2dp_source"
          "hsp_hs"
          "hsp_ag"
          "hfp_hf"
          "hfp_ag"
        ];
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
      };

      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
    };
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
      "camera"
      "scanner"
      "lp"
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
        HandlePowerKey = "poweroff";
      };
    };
  };

  # Framework AMD laptops are tuned for power-profiles-daemon; keep it as the
  # single power policy daemon to avoid suspend/resume conflicts.
  services.power-profiles-daemon.enable = true;
  services.auto-cpufreq.enable = false;
  services.tlp.enable = false;

  # Enable base suspend/resume hooks.
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
    exfatprogs
    flatpak
    nh
    sane-airscan
    sane-backends
    simple-scan
    wget
  ];

  programs.steam.enable = true;
  programs.nix-index-database.comma.enable = true;

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "jet" ];
  };

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
    # Disable autosuspend for Framework devices that have shown resume issues.
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="27c6", ATTR{idProduct}=="609c", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="32ac", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{class}=="0x0c0330", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="platform", KERNEL=="USBC000:00", ATTR{power/control}="on"
  '';

  system.stateVersion = "25.05";

}
