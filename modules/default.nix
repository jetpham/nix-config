{ inputs, pkgs, config, ... }:

{
    home.stateVersion = "21.03";
    imports = [
        # gui
        ./firefox
        ./eww
        ./dunst
        ./hyprland
        ./wofi

        # cli
        ./nvim
        ./zsh
        ./git
        ./direnv

        # system
        ./xdg
	    ./packages
    ];
}
