{ ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Experimental = true;
      MultiProfile = "multiple";
    };
  };

  services.blueman.enable = true;
}
