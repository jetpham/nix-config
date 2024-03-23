{ config, lib, inputs, ...}:

{
    imports = [ ../../modules/default.nix ];
    config.modules = {
        # gui
        firefox.enable = true;
        kitty.enable = true;
        eww.enable = true;
        dunst.enable = true;
        hyprland.enable = true;
        wofi.enable = true;

        # cli
        nvim.enable = true;
        git.enable = true;
        nushell.enable = true;
        direnv.enable = true;

        # system
        xdg.enable = true;
        packages.enable = true;
    };
}
