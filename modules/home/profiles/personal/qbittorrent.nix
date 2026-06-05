{
  config,
  pkgs,
  ...
}:

let
  configureQbittorrentTailscale = pkgs."configure-qbittorrent-tailscale";
  qbittorrentTailscale = pkgs."qbittorrent-tailscale";
in

{
  home.activation.configureQbittorrentTailscale = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${configureQbittorrentTailscale}/bin/configure-qbittorrent-tailscale
  '';

  home.file.".local/share/applications/org.qbittorrent.qBittorrent.desktop".text = ''
    [Desktop Entry]
    Categories=Network;FileTransfer;P2P;Qt;
    Exec=${qbittorrentTailscale}/bin/qbittorrent %U
    GenericName=BitTorrent client
    Comment=Download and share files over BitTorrent
    Icon=qbittorrent
    MimeType=application/x-bittorrent;x-scheme-handler/magnet;
    Name=qBittorrent
    Terminal=false
    Type=Application
    StartupNotify=false
    StartupWMClass=qbittorrent
    Keywords=bittorrent;torrent;magnet;download;p2p;
    SingleMainWindow=true
  '';

  home.packages = [ qbittorrentTailscale ];
}
