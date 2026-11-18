{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.jackett) dataDir port;
  tailscaleDevice = "sys-subsystem-net-devices-tailscale0.device";
in

{
  services.jackett = {
    enable = true;
    openFirewall = false;
  };

  services.flaresolverr = {
    enable = true;
    openFirewall = false;
  };

  systemd.services.flaresolverr = {
    # systemd resolves the interface allowlist before ExecStartPre. Waiting for
    # the daemon alone can leave the allowlist with only lo during boot.
    requires = [ tailscaleDevice ];
    after = [
      "tailscaled.service"
      tailscaleDevice
    ];
    wants = [ "tailscaled.service" ];
    environment.HOST = "127.0.0.1";
    serviceConfig.RestrictNetworkInterfaces = [
      "lo"
      "tailscale0"
    ];
  };

  systemd.services.jackett = {
    requires = [ tailscaleDevice ];
    after = [
      "tailscaled.service"
      tailscaleDevice
      "flaresolverr.service"
    ];
    wants = [
      "tailscaled.service"
      "flaresolverr.service"
    ];
    path = [
      pkgs.coreutils
      pkgs.jq
    ];
    # Preserve the generated key and indexer state in the private runtime file.
    preStart = ''
      umask 077
      server_config='${dataDir}/ServerConfig.json'
      temporary=$(mktemp "$server_config.XXXXXX")
      trap 'rm -f -- "$temporary"' EXIT
      if [ -f "$server_config" ]; then
        jq '.FlareSolverrUrl = "http://127.0.0.1:${toString config.services.flaresolverr.port}" | .AllowExternal = false' \
          "$server_config" > "$temporary"
      else
        printf '%s\n' '{"FlareSolverrUrl":"http://127.0.0.1:${toString config.services.flaresolverr.port}","AllowExternal":false}' \
          > "$temporary"
      fi
      mv "$temporary" "$server_config"
      trap - EXIT
    '';
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.jackett}/bin/Jackett --NoUpdates --ListenPrivate --Port ${toString port} --DataFolder '${dataDir}'";
      RestrictNetworkInterfaces = [
        "lo"
        "tailscale0"
      ];
    };
  };
}
