# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];
  
  # Boot time optimizations
  boot.loader.timeout = 0; # Boot immediately without waiting for user input
  
  # Disable slow services that delay boot

  networking.hostName = "framework"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  
  # Optimize network configuration for faster boot
  
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

  services.resolved = {
    enable = true;
  };

  networking.firewall.checkReversePath = "loose";

  services.tailscale.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Framework Laptop 13 AMD AI 300 Series specific configurations
  # Enable AMD GPU support and power management
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Add OpenCL support for CPU-based operations
    extraPackages = with pkgs; [ pocl ];
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

  # Set Kitty as default terminal
  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [ "kitty.desktop" ];
    };
  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Remove default GNOME apps (keeping loupe and file-roller)
  environment.gnome.excludePackages = with pkgs; [
    epiphany          # GNOME Web
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
    snapshot          # Camera
    gnome-text-editor
    simple-scan
    totem             # Videos (have VLC)
    yelp              # Help docs
    evince            # PDF viewer (using Zen Browser)
    geary             # Email
    gnome-tour
    gnome-font-viewer # Have font-manager
  ];
  
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.jet = {
    isNormalUser = true;
    description = "Jet";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" "render" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Framework-specific services
  # Enable fwupd for BIOS updates (distributed through LVFS)
  services.fwupd.enable = true;
  
  # Enable automatic garbage collection to prevent old generations from slowing boot
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Optimize Nix for RAM - use more memory for builds
  nix.settings = {
    max-jobs = "auto"; # Use all CPU cores
    cores = 0; # Use all cores
    # Build in RAM via tmpfs (configured above)
    build-users-group = "nixbld";
  };

  # Power management for laptop
  # Configure lid switch behavior - suspend (no swap needed with 96GB RAM)
  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
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

  # Enable thermald for thermal management
  services.thermald.enable = true;

  # Framework Laptop 13 specific power optimizations
  # Enable power-profiles-daemon for better AMD power management
  # (Note: This conflicts with auto-cpufreq, so we'll keep auto-cpufreq disabled)
  services.power-profiles-daemon.enable = false;
  
  # AMD specific power management
  powerManagement.cpuFreqGovernor = "powersave";

  # Enable power management
  powerManagement.enable = true;

  # RAM optimizations for 96GB system
  # Disable swap usage (set swappiness to 0) - with 96GB RAM, never need swap
  boot.kernel.sysctl = {
    "vm.swappiness" = 0; # Never swap to disk
    "vm.vfs_cache_pressure" = 50; # Keep more filesystem cache in RAM
    "vm.dirty_ratio" = 15; # Write to disk when 15% of RAM is dirty
    "vm.dirty_background_ratio" = 5; # Start writing when 5% dirty
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

  # RAM disk for Nix build cache - speeds up compilation significantly
  fileSystems."/tmp/nix-build" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=32G" # 32GB for Nix builds
      "mode=1777"
      "nosuid"
      "nodev"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  git
  helix # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  wget
  vim
  docker
  docker-compose
  nh
  ];

  environment.variables.EDITOR = "helix";
  environment.sessionVariables = {
    TERMINAL = "kitty";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Enable rootless Docker
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # Create docker group
  users.groups.docker = {
    name = "docker";
  };

  # https://wiki.nixos.org/wiki/Appimage#Register_AppImage_files_as_a_binary_type_to_binfmt_misc
  programs.appimage = {
  enable = true;
  binfmt = true;
  };

  # GameCube adapter udev rules for Slippi/Dolphin
  services.udev.extraRules = ''
    # GameCube adapter USB device (vendor ID 057e, product ID 0337)
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
    # GameCube adapter HID device (needed for Dolphin to access controllers)
    KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666", GROUP="input"
  '';

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Set user profile picture for GNOME
  system.activationScripts.script.text = ''
    mkdir -p /var/lib/AccountsService/{icons,users}
    if [ -f /home/jet/Documents/nix-config/cat.png ]; then
      cp /home/jet/Documents/nix-config/cat.png /var/lib/AccountsService/icons/jet
      echo -e "[User]\nIcon=/var/lib/AccountsService/icons/jet\n" > /var/lib/AccountsService/users/jet
      chown root:root /var/lib/AccountsService/users/jet
      chmod 0600 /var/lib/AccountsService/users/jet
      chown root:root /var/lib/AccountsService/icons/jet
      chmod 0444 /var/lib/AccountsService/icons/jet
    fi
  '';

}
