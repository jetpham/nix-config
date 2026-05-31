{ ... }:

{
  imports = [
    ../../configuration.nix
    ./hardware-configuration.nix
    ./oneleet-agent.nix
  ];

  networking.hostName = "framework-work";

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
