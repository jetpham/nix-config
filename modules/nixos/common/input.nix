{ pkgs, ... }:

{
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings.main = {
          capslock = "esc";
          esc = "capslock";
          leftalt = "leftcontrol";
          leftcontrol = "leftalt";
          mute = "mute";
          volumedown = "playpause";
          volumeup = "volumedown";
          previoussong = "volumeup";
          playpause = "command(touch /tmp/keyd-f5-test)";
          nextsong = "noop";
          brightnessdown = "noop";
          brightnessup = "noop";
          rfkill = "brightnessdown";
          sysrq = "brightnessup";
          media = "sysrq";
        };
      };
      frameworkRadio = {
        ids = [ "32ac:0006" ];
        settings.main = {
          brightnessdown = "noop";
          brightnessup = "noop";
          rfkill = "brightnessdown";
        };
      };
    };
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [Serial Keyboards]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';
}
