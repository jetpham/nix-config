{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.foot;

in {
    options.modules.foot = { enable = mkEnableOption "foot"; };
    config = mkIf cfg.enable {
        programs.kitty = {
            enable = true;
            extraConfig = buildins.readFile ./kitty.conf;
        };
    };
}
