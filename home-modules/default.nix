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
    ./sway.nix
    ./opencode.nix
  ];
}
