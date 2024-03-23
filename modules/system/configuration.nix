{ config, pkgs, inputs, ... }:

{
    # Remove unecessary preinstalled packages
    environment.defaultPackages = [ ];
    services.xserver.desktopManager.xterm.enable = false;

    programs.zsh.enable = true;

    # Laptop-specific packages (the other ones are installed in `packages.nix`)
    environment.systemPackages = with pkgs; [
        acpi tlp git
    ];

    # Install fonts
    fonts = {
        packages = with pkgs; [
            jetbrains-mono
            roboto
            openmoji-color
            (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
        ];

        fontconfig = {
            hinting.autohint = true;
            defaultFonts = {
              emoji = [ "OpenMoji Color" ];
            };
        };
    };


    # Wayland stuff: enable XDG integration, allow sway to use brillo
xdg = {
    portal = {
        enable = true;
        extraPortals = with pkgs; [
            xdg-desktop-portal-wlr
            xdg-desktop-portal-gtk
        ];
        config = {
            common = {
                default = "gtk";
            };
            preferred = {
                "org.freedesktop.impl.portal.Screencast" = "wlr";
            };
        };
    };
};


    # Nix settings, auto cleanup and enable flakes
    nix = {
        settings.auto-optimise-store = true;
        settings.allowed-users = [ "jet" ];
        gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 7d";
        };
        extraOptions = ''
            experimental-features = nix-command flakes
            keep-outputs = true
            keep-derivations = true
        '';
    };

    # Boot settings: clean /tmp/, latest kernel and enable bootloader
    boot = {
        tmp.cleanOnBoot = true;
        loader = {
        systemd-boot.enable = true;
        systemd-boot.editor = false;
        efi.canTouchEfiVariables = true;
        timeout = 0;
        };
    };

    # Set up locales (timezone and keyboard layout)
    time.timeZone = "America/Los_Angeles";
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };

    # Set up user and enable sudo
    users.users.jet = {
        isNormalUser = true;
        extraGroups = [ "input" "wheel" "networkmanager"];
        shell = pkgs.zsh;
    };

    # Set up networking and secure it
    networking = {
        # Enable networking
        networkmanager.enable = true;
        firewall = {
            #enable = true;
            #allowedTCPPorts = [ 443 80 ];
            #allowedUDPPorts = [ 443 80 44857 ];
            #allowPing = false;
        };
    };

    # Set environment variables
    environment.variables = {
        NIXOS_CONFIG = "$HOME/.config/nixos/configuration.nix";
        NIXOS_CONFIG_DIR = "$HOME/.config/nixos/";
        XDG_DATA_HOME = "$HOME/.local/share";
        PASSWORD_STORE_DIR = "$HOME/.local/share/password-store";
        GTK_RC_FILES = "$HOME/.local/share/gtk-1.0/gtkrc";
        GTK2_RC_FILES = "$HOME/.local/share/gtk-2.0/gtkrc";
        MOZ_ENABLE_WAYLAND = "1";
        ZK_NOTEBOOK_DIR = "$HOME/stuff/notes/";
        EDITOR = "nvim";
        DIRENV_LOG_FORMAT = "";
        ANKI_WAYLAND = "1";
        DISABLE_QT5_COMPAT = "0";
        GTK_USE_PORTAL = "1";
    };

    # Security 
    security = {
        # Extra security
        protectKernelImage = true;
    };
  # Allow unfree package
  nixpkgs.config.allowUnfree = true;

      # Enable sound with pipewire.
    sound.enable = true;
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
  };

    # enable pulseaudio, enable opengl (for Wayland)
    hardware = {
        bluetooth.enable = true;
        opengl = {
            enable = true;
            driSupport = true;
        };
    };

    # Do not touch
    system.stateVersion = "23.11";
}
