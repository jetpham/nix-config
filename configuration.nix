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

  # Enable networking
  networking.networkmanager.enable = true;

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
    extraGroups = [ "networkmanager" "wheel" "docker" ];
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

  # Power management for laptop
  # Configure lid switch behavior - hybrid-sleep for optimal power management
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
  
  # Enable ZRAM swap for better memory management and potentially faster boot
  zramSwap = {
    enable = true;
    algorithm = "zstd";
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
    cp /home/jet/Documents/nixos-config/cat.png /var/lib/AccountsService/icons/jet
    echo -e "[User]\nIcon=/var/lib/AccountsService/icons/jet\n" > /var/lib/AccountsService/users/jet

    chown root:root /var/lib/AccountsService/users/jet
    chmod 0600 /var/lib/AccountsService/users/jet

    chown root:root /var/lib/AccountsService/icons/jet
    chmod 0444 /var/lib/AccountsService/icons/jet
  '';

}
