{ ... }:

{
  networking.networkmanager = {
    enable = true;
    settings = {
      connection."wifi.powersave" = 2;
      device."wifi.scan-rand-mac-address" = false;
    };
  };

  networking.firewall.enable = true;

  services.resolved.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
