{
  config,
  pkgs,
  ...
}:

let
  configureQbittorrentTailscale = pkgs."configure-qbittorrent-tailscale";
  qbittorrentTailscale = pkgs."qbittorrent-tailscale";
  searchPlugins = pkgs.fetchFromGitHub {
    owner = "qbittorrent";
    repo = "search-plugins";
    rev = "2beb5c67b0edbf2387a031a02d1881fab4bec3c3";
    hash = "sha256-0jylqhLqv6e2k4RaKbacBulHa7ZLuD/fAPI8X/rlszM=";
  };
  configureQbittorrentSearch = pkgs.writeShellApplication {
    name = "configure-qbittorrent-search";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      engines="''${XDG_DATA_HOME:-$HOME/.local/share}/qBittorrent/nova3/engines"
      install -d -m 0700 "$engines"

      for plugin in jackett limetorrents piratebay torrentscsv; do
        install -m 0600 "${searchPlugins}/nova3/engines/$plugin.py" "$engines/$plugin.py"
      done

      # Torznab Books is 7000; 8000 is Other and hides manga results.
      sed -i "/'books':/s/8000/7000/" "$engines/jackett.py"

      for plugin in eztv solidtorrents torlock torrentproject; do
        rm -f -- "$engines/$plugin.py" "$engines/$plugin.ico"
      done
    '';
  };
  linkQbittorrentJackett = pkgs.writeShellApplication {
    name = "link-qbittorrent-jackett";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      server_config=/var/lib/jackett/.config/Jackett/ServerConfig.json
      plugin_config="''${XDG_DATA_HOME:-$HOME/.local/share}/qBittorrent/nova3/engines/jackett.json"

      if ! systemctl is-active --quiet jackett.service; then
        printf '%s\n' 'Jackett is not active. Activate the NixOS configuration and start Jackett first.' >&2
        exit 1
      fi

      api_key=$(sudo ${pkgs.jq}/bin/jq -er \
        '.APIKey | select(type == "string" and test("^[a-z0-9]{32}$"))' \
        "$server_config") || {
        printf 'Could not read a valid API key from %s.\n' "$server_config" >&2
        exit 1
      }

      install -d -m 0700 "$(dirname "$plugin_config")"
      temporary=$(mktemp "$plugin_config.XXXXXX")
      trap 'rm -f -- "$temporary"' EXIT
      jq -n --arg api_key "$api_key" '{
        api_key: $api_key,
        url: "http://127.0.0.1:9117",
        tracker_first: false,
        thread_count: 20
      }' > "$temporary"
      chmod 0600 "$temporary"
      mv "$temporary" "$plugin_config"
      trap - EXIT
      unset api_key

      printf 'Linked qBittorrent to the local Jackett service.\n'
    '';
  };
in

{
  home.activation.configureQbittorrentTailscale = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${configureQbittorrentTailscale}/bin/configure-qbittorrent-tailscale
    ${configureQbittorrentSearch}/bin/configure-qbittorrent-search
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

  home.packages = [
    linkQbittorrentJackett
    qbittorrentTailscale
  ];
}
