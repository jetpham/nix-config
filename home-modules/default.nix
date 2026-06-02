{ ... }:

{
  imports = [
    ./lib.nix
    ./core.nix
    ./packages.nix
    ./git.nix
    ./shell.nix
    ./terminal.nix
    ./browser.nix
    ./desktop.nix
    ./qbittorrent.nix
    ./opencode.nix
  ];
}
