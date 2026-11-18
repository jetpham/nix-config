{ pkgs, ... }:

{
  # GE-Proton can use the kernel's Windows synchronization primitives.
  boot.kernelModules = [ "ntsync" ];

  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];
}
