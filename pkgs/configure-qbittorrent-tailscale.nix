{
  coreutils,
  crudini,
  writeShellApplication,
}:

writeShellApplication {
  name = "configure-qbittorrent-tailscale";
  runtimeInputs = [
    coreutils
    crudini
  ];
  text = ''
    conf="''${XDG_CONFIG_HOME:-$HOME/.config}/qBittorrent/qBittorrent.conf"
    mkdir -p "$(dirname "$conf")"

    crudini --set "$conf" BitTorrent 'Session\Interface' tailscale0
    crudini --set "$conf" BitTorrent 'Session\InterfaceName' tailscale0
    crudini --set "$conf" BitTorrent 'Session\LSDEnabled' false
    crudini --del "$conf" BitTorrent 'Session\InterfaceAddress' 2>/dev/null || true
  '';
}
