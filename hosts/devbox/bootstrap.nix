{ lib, ... }:

{
  imports = [ ./default.nix ];

  services.openssh = {
    enable = lib.mkForce true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
