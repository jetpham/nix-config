{ ... }:

{
  imports = [
    ./app-compat.nix
    ./audio.nix
    ./bluetooth.nix
    ./boot.nix
    ./desktop-gnome.nix
    ./fonts.nix
    ./framework-hardware.nix
    ./input.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./power.nix
    ./secrets.nix
    ./users.nix
    ./virtualisation.nix
  ];

  system.stateVersion = "25.05";
}
