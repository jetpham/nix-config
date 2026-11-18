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
    crudini --set "$conf" Network PortForwardingEnabled false
    # Jackett covers these two sources; retain their scripts for manual fallback.
    crudini --set "$conf" SearchEngines disabledEngines 'eztv, limetorrents, piratebay, solidtorrents, torlock, torrentproject'
    crudini --del "$conf" BitTorrent 'Session\InterfaceAddress' 2>/dev/null || true
  '';
}
