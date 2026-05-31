{ config, lib, ... }:

let
  hasLuksDevice = config.boot.initrd.luks.devices != { };
in

{
  imports = [
    ../../configuration.nix
    ./hardware-configuration.nix
    ./oneleet-agent.nix
  ];

  networking.hostName = "framework-work";

  # Once root is LUKS-encrypted, the disk passphrase is the boot password.
  # GDM autologin avoids entering a second password after the disk is unlocked.
  services.displayManager.autoLogin = {
    enable = hasLuksDevice;
    user = "jet";
  };

  swapDevices = lib.mkForce [ ];

  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=8G"
      "mode=1777"
      "nosuid"
      "nodev"
    ];
  };
}
