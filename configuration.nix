{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.hostName = "framework";

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true; # Show battery charge of Bluetooth devices
      };
    };
  };

  networking.networkmanager.enable = true;

  services.resolved.enable = true;

  networking.firewall.enable = true;
  # Required for Tailscale
  networking.firewall.checkReversePath = "loose";

  services.tailscale.enable = true;

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

  # Set Kitty as default terminal
  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [ "kitty.desktop" ];
    };
  };

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome.sushi.enable = true;

  # Remove default GNOME apps (keeping loupe and file-roller)
  environment.gnome.excludePackages = with pkgs; [
    epiphany # GNOME Web
    gnome-calculator
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-connections
    gnome-console
    gnome-contacts
    gnome-maps
    gnome-music
    gnome-weather
    snapshot # Camera
    gnome-text-editor
    simple-scan
    totem # Videos (have VLC)
    yelp # Help docs
    evince # PDF viewer (using Zen Browser)
    geary # Email
    gnome-tour
    gnome-font-viewer # Have font-manager
    nautilus # Using Nemo
  ];

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

  # Use RAM disk (tmpfs) for temporary files - much faster than disk
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=32G" # Use up to 32GB RAM for /tmp (adjust as needed)
      "mode=1777"
      "nosuid"
      "nodev"
    ];
  };

  environment.systemPackages = with pkgs; [
    bubblewrap
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
