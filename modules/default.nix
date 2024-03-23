{ inputs, pkgs, config, ... }:

{
    home.stateVersion = "21.03";
    imports = [
        # gui
        ./firefox
        ./eww
        ./dunst
        ./kitty
        ./hyprland
        ./wofi

        # cli
        ./nvim
        ./nushell
        ./git
        ./direnv

        # system
        ./xdg
	    ./packages
    ];
}
