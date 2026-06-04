{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:

let
  isPersonal = hostname == "framework";

  configureQbittorrentTailscale = pkgs.writeShellApplication {
    name = "configure-qbittorrent-tailscale";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.crudini
    ];
    text = ''
      conf="''${XDG_CONFIG_HOME:-$HOME/.config}/qBittorrent/qBittorrent.conf"
      mkdir -p "$(dirname "$conf")"

      crudini --set "$conf" BitTorrent 'Session\Interface' tailscale0
      crudini --set "$conf" BitTorrent 'Session\InterfaceName' tailscale0
      crudini --set "$conf" BitTorrent 'Session\LSDEnabled' false
      crudini --del "$conf" BitTorrent 'Session\InterfaceAddress' 2>/dev/null || true
    '';
  };

  qbittorrentTailscale = pkgs.symlinkJoin {
    name = "qbittorrent-enhanced-tailscale";
    paths = [ pkgs.qbittorrent-enhanced ];
    postBuild = ''
      rm -f "$out/bin/qbittorrent"
      # Enforce qBittorrent's bind settings, then add a systemd interface allowlist.
      # RestrictNetworkInterfaces works for transient services, not transient scopes.
      cat > "$out/bin/qbittorrent" <<'EOF'
      #!${pkgs.runtimeShell}
      set -eu

      ${configureQbittorrentTailscale}/bin/configure-qbittorrent-tailscale

      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        printf '%s\n' 'qBittorrent not started: XDG_RUNTIME_DIR is not set, so systemd cannot apply the Tailscale-only network restriction.' >&2
        exit 1
      fi

      exec ${pkgs.systemd}/bin/systemd-run \
        --user \
        --quiet \
        --collect \
        --property='RestrictNetworkInterfaces=lo tailscale0' \
        -- \
        ${pkgs.qbittorrent-enhanced}/bin/qbittorrent "$@"
      EOF
      chmod +x "$out/bin/qbittorrent"

      desktop="$out/share/applications/org.qbittorrent.qBittorrent.desktop"
      if [ -e "$desktop" ]; then
        rm -f "$desktop"
        install -Dm644 ${pkgs.qbittorrent-enhanced}/share/applications/org.qbittorrent.qBittorrent.desktop "$desktop"
        substituteInPlace "$desktop" \
          --replace-fail 'Exec=qbittorrent %U' "Exec=$out/bin/qbittorrent %U"
      fi
    '';
  };
in

lib.mkIf isPersonal {
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
