{ ... }:

{
  imports = [
    ../../configuration.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "framework";

  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=32G"
      "mode=1777"
      "nosuid"
      "nodev"
    ];
  };
}
