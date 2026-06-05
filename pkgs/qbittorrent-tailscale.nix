{
  configureQbittorrentTailscale,
  qbittorrent-enhanced,
  runtimeShell,
  symlinkJoin,
  systemd,
}:

symlinkJoin {
  name = "qbittorrent-enhanced-tailscale";
  paths = [ qbittorrent-enhanced ];
  postBuild = ''
    rm -f "$out/bin/qbittorrent"
    cat > "$out/bin/qbittorrent" <<'EOF'
    #!${runtimeShell}
    set -eu

    ${configureQbittorrentTailscale}/bin/configure-qbittorrent-tailscale

    if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
      printf '%s\n' 'qBittorrent not started: XDG_RUNTIME_DIR is not set, so systemd cannot apply the Tailscale-only network restriction.' >&2
      exit 1
    fi

    exec ${systemd}/bin/systemd-run \
      --user \
      --quiet \
      --collect \
      --property='RestrictNetworkInterfaces=lo tailscale0' \
      -- \
      ${qbittorrent-enhanced}/bin/qbittorrent "$@"
    EOF
    chmod +x "$out/bin/qbittorrent"

    desktop="$out/share/applications/org.qbittorrent.qBittorrent.desktop"
    if [ -e "$desktop" ]; then
      rm -f "$desktop"
      install -Dm644 ${qbittorrent-enhanced}/share/applications/org.qbittorrent.qBittorrent.desktop "$desktop"
      substituteInPlace "$desktop" \
        --replace-fail 'Exec=qbittorrent %U' "Exec=$out/bin/qbittorrent %U"
    fi
  '';
}
