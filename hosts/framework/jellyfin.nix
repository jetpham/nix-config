{
  config,
  lib,
  pkgs,
  ...
}:

let
  library = "/home/jet/Documents/Media";
  credentials = "/home/jet/Documents/jellyfin-setup/credentials";
  addresses = pkgs.writeShellApplication {
    name = "jellyfin-addresses";
    runtimeInputs = [
      pkgs.iproute2
      pkgs.python3
    ];
    text = ''
      python3 - <<'PY'
      import json, subprocess
      print("On this laptop: http://localhost:8096")
      print("Through Tailscale: http://framework:8096")
      for interface in json.loads(subprocess.check_output(["ip", "-j", "-4", "addr"], text=True)):
          name = interface["ifname"]
          if name not in {"pixel-usb", "wlp192s0"}:
              continue
          for address in interface["addr_info"]:
              ip = address["local"]
              if name == "pixel-usb" or ip == "10.42.0.1":
                  label = "USB cable" if name == "pixel-usb" else "Laptop hotspot"
                  print(f"{label}: http://{ip}:8096")
      PY
    '';
  };
  login = pkgs.writeShellApplication {
    name = "jellyfin-login";
    runtimeInputs = [
      pkgs.coreutils
      addresses
    ];
    text = ''
      printf 'Username: jet\nInitial password: '
      cat ${credentials}/admin-password
      printf '\n'
      jellyfin-addresses
    '';
  };
  hotspot = pkgs.writeShellApplication {
    name = "media-hotspot";
    runtimeInputs = [
      pkgs.networkmanager
      addresses
    ];
    text = ''
      nmcli connection up 'Framework media hotspot'
      jellyfin-addresses
    '';
  };
in
{
  services.jellyfin = {
    enable = true;
    # Limit access to the Pixel, the direct USB connection, and the hotspot.
    openFirewall = false;
    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
      device = "/dev/dri/renderD128";
    };
    transcoding = {
      enableHardwareEncoding = true;
      throttleTranscoding = true;
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        hevc10bit = true;
        vp9 = true;
        av1 = true;
      };
    };
  };
  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];
  systemd.services.jellyfin = {
    unitConfig.RequiresMountsFor = [ library ];
    serviceConfig = {
      # Expose only the curated library, without opening jet's private home.
      ProtectHome = true;
      BindReadOnlyPaths = [ "${library}:/media" ];
    };
  };
  systemd.services.jellyfin-bootstrap = {
    description = "Initialize Framework's Jellyfin account and libraries once";
    wantedBy = [ "multi-user.target" ];
    after = [ "jellyfin.service" ];
    requires = [ "jellyfin.service" ];
    unitConfig.ConditionPathExists = "!${config.services.jellyfin.dataDir}/.framework-bootstrap-complete";
    serviceConfig = {
      Type = "oneshot";
      User = "jellyfin";
      Group = "jellyfin";
      LoadCredential = [ "admin-password:${credentials}/admin-password" ];
      ExecStart = "${pkgs.python3}/bin/python3 ${./jellyfin-bootstrap.py}";
      TimeoutStartSec = 240;
      UMask = "0077";
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ config.services.jellyfin.dataDir ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # Give this particular Pixel a stable interface name, independent of USB port.
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", ATTRS{serial}=="57220DLCR004QW", NAME:="pixel-usb"
  '';
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ "${credentials}/hotspot.env" ];
    profiles = {
      framework-media-hotspot = {
        connection = {
          id = "Framework media hotspot";
          uuid = "68ef9176-34d8-4e31-85bb-f77c9736ef89";
          type = "wifi";
          interface-name = "wlp192s0";
          autoconnect = false;
        };
        wifi = {
          mode = "ap";
          ssid = "framework";
          band = "a";
          channel = 149;
          channel-width = 80;
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$JELLYFIN_HOTSPOT_PSK";
        };
        ipv4 = {
          method = "shared";
          address1 = "10.42.0.1/24";
          never-default = true;
        };
        ipv6.method = "disabled";
      };
      framework-pixel-usb = {
        connection = {
          id = "Pixel USB local media";
          uuid = "fc4b60d2-84a1-49ee-b250-b598bdf822b4";
          type = "ethernet";
          interface-name = "pixel-usb";
          autoconnect = true;
          autoconnect-priority = 100;
        };
        ipv4 = {
          method = "auto";
          never-default = true;
          ignore-auto-dns = true;
          route-metric = 2000;
        };
        ipv6 = {
          method = "auto";
          never-default = true;
          ignore-auto-dns = true;
          route-metric = 2000;
        };
      };
    };
  };
  networking.firewall = {
    interfaces.pixel-usb = {
      allowedTCPPorts = [ 8080 8096 ];
      allowedUDPPorts = [ 7359 ];
    };
    # DHCP requests originate from 0.0.0.0 before the phone has an address.
    interfaces.wlp192s0.allowedUDPPorts = [ 67 ];
    extraCommands = lib.mkAfter (
      ''
        iptables -w -A nixos-fw -i tailscale0 -s 100.106.98.89/32 -p tcp --dport 8096 -j nixos-fw-accept
        iptables -w -A nixos-fw -i tailscale0 -s 100.106.98.89/32 -p tcp --dport 8080 -j nixos-fw-accept
        iptables -w -A nixos-fw -i wlp192s0 -s 10.42.0.0/24 -p tcp -m multiport --dports 53,8080,8096 -j nixos-fw-accept
        iptables -w -A nixos-fw -i wlp192s0 -s 10.42.0.0/24 -p udp -m multiport --dports 53,7359 -j nixos-fw-accept
      ''
      + lib.optionalString config.networking.enableIPv6 ''
        ip6tables -w -A nixos-fw -i tailscale0 -s fd7a:115c:a1e0::1433:6259/128 -p tcp --dport 8096 -j nixos-fw-accept
        ip6tables -w -A nixos-fw -i tailscale0 -s fd7a:115c:a1e0::1433:6259/128 -p tcp --dport 8080 -j nixos-fw-accept
      ''
    );
  };
  environment.systemPackages = [
    pkgs.jellyfin-desktop
    addresses
    login
    hotspot
  ];
}
