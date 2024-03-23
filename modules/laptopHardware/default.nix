{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.laptopHardware;

in {
    options.modules.laptopHardware = { enable = mkEnableOption "laptopHardware"; };
    config = mkIf cfg.enable {
        
    };
}
