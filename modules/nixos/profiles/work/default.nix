{ lib, ... }:

{
  imports = [ ./oneleet-agent.nix ];

  zramSwap.enable = lib.mkForce false;
}
