{
  config,
  homePackages,
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
    ../../modules/home/common
    ./home-qbittorrent.nix
    ./home-media.nix
    ./home-vpn-toggle.nix
  ];

  programs.codexDesktopLinux = {
    enable = true;
    cliPackage = pkgs.codex;
    remoteMobileControl.enable = true;
  };

  # Keep the GNOME capture extension on the same revision as the T3 desktop.
  xdg.dataFile."gnome-shell/extensions/snap-shot@t3.codes".source =
    "${pkgs.t3code-unwrapped-nightly.src}/apps/desktop/gnome-extension";
  dconf.settings."org/gnome/shell".enabled-extensions = [ "snap-shot@t3.codes" ];

  # Let Mutter match Xwayland rendering to the display scale. A global 1.0
  # override makes legacy apps blurry on the laptop's 200% display.
  dconf.settings."org/gnome/mutter/wayland".xwayland-scaling-factor = 0.0;

  # The desktop is a client of the system service, which owns ~/.t3's database.
  # Preserve window preferences and other app-managed settings.
  home.activation.t3DesktopClient = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.t3/userdata/desktop-settings.json"
    run mkdir -p "$(dirname "$settings")"
    if [ -z "''${DRY_RUN_CMD:-}" ]; then
      temporary=$(mktemp "$settings.XXXXXX")
      if [ -f "$settings" ]; then
        ${pkgs.jq}/bin/jq '.localEnvironmentEnabled = false' "$settings" > "$temporary"
      else
        printf '%s\n' '{"localEnvironmentEnabled":false}' > "$temporary"
      fi
      chmod 600 "$temporary"
      mv "$temporary" "$settings"
    fi
  '';

  home.file.".codex/AGENTS.md".text = ''
    # Framework Context

    - This machine is `framework`, the user's NixOS laptop and an interactive Codex host.
    - Keep local project work under `~/Documents`.

    # Development Previews

    - Use an available TCP port from `5100-5199` for development previews.
    - Bind preview servers to `0.0.0.0` so the user's Pixel can reach them through Tailscale.
    - Report the preview URL as `http://framework:<port>`.
    - Keep databases, debuggers, browser control ports, and other internal services on localhost.

    # NixOS Rules

    - Prefer declarative Nix configuration for persistent tools and services.
    - If a repository has `flake.nix`, use its dev shell and treat it as the source of truth for project tooling.
    - Do not run a NixOS system switch unless the user explicitly asks.
  '';

  home.packages = with pkgs; [
    darktable
    digikam
    element-desktop
    exiftool
    foliate
    kdePackages.kdenlive
    obs-studio
    prismlauncher
    rapid-photo-downloader
    signal-desktop
    t3code
    vesktop
    vlc
    yacreader
    zulip

    gnomeExtensions.tailscale-qs
    homePackages.evilBitToggleExtension
  ];
}
