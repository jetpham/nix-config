{
  inputs,
  pkgs,
  lib,
  config,
  modulesPath,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # c
    gcc
    gdb
    gnumake
    clang
    clang-tools

    # nix
    nil
    alejandra

    # else
    bat
    wget
    firefox
    git
    tree
    neovim
    nushell
    kitty
  ];

  hardware.bluetooth.enable = true;

  networking.networkmanager.enable = true;
  services.automatic-timezoned.enable = true;
  services.xserver.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.xkb.layout = "us";

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "bat";
  };
  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "bat";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "usb_storage" "sd_mod"];
  # boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  # boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/ecfaab5f-dc2e-4bf0-a4cc-9a873de92c6f";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5426-5447";
    fsType = "vfat";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/db16204a-f762-4252-a7bb-1ff4f333fc17";}
  ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  fonts.packages = with pkgs; [
    noto-fonts-cjk
    noto-fonts-color-emoji
  ];

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

  users.users.jet = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    shell = pkgs.nushell;
  };
  home-manager.useGlobalPkgs = true;
  home-manager.users.jet = import ./home.nix {inherit inputs pkgs;};

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    trusted-users = ["root" "@wheel"];
  };
  nixpkgs.config = {allowUnfree = true;};

  networking.hostName = "laptop";

  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
