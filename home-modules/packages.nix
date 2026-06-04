{
  inputs,
  pkgs,
  homeLib,
  hostname,
  ...
}:

let
  isWork = hostname == "framework-work";
  isPersonal = hostname == "framework";

  evilBitCtl = pkgs.writeShellApplication {
    name = "evil-bitctl";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.nftables
    ];
    text = ''
      state_dir=/run/evil-bit-toggle
      state_file="$state_dir/enabled"
      table=evil_bit
      chain=output

      usage() {
        printf 'Usage: evil-bitctl {enable|disable|status}\n' >&2
        exit 64
      }

      enable() {
        nft add table ip "$table" 2>/dev/null || true

        if nft list chain ip "$table" "$chain" >/dev/null 2>&1; then
          nft flush chain ip "$table" "$chain"
        else
          nft add chain ip "$table" "$chain" '{ type route hook output priority mangle; policy accept; }'
        fi

        nft add rule ip "$table" "$chain" ip frag-off set ip frag-off '|' 0x8000
        install -d -m 0755 "$state_dir"
        touch "$state_file"
      }

      disable() {
        nft delete table ip "$table" 2>/dev/null || true
        rm -f "$state_file"
        rmdir "$state_dir" 2>/dev/null || true
      }

      status() {
        if [ -e "$state_file" ] && nft list table ip "$table" >/dev/null 2>&1; then
          printf 'enabled\n'
        else
          printf 'disabled\n'
        fi
      }

      case "''${1:-}" in
        enable)
          enable
          ;;
        disable)
          disable
          ;;
        status)
          status
          ;;
        *)
          usage
          ;;
      esac
    '';
  };

  reducedMotionToggleExtension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-reduced-motion-toggle";
    version = "1";
    src = ../gnome-extensions/reduced-motion-toggle;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/gnome-shell/extensions/reduced-motion-toggle@jetpham.github.com"
      cp -r . "$out/share/gnome-shell/extensions/reduced-motion-toggle@jetpham.github.com"

      runHook postInstall
    '';
  };

  evilBitToggleExtension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-evil-bit-toggle";
    version = "1";
    src = ../gnome-extensions/evil-bit-toggle;

    installPhase = ''
      runHook preInstall

      substituteInPlace extension.js \
        --replace-fail @evilBitCtl@ ${evilBitCtl}/bin/evil-bitctl

      mkdir -p "$out/share/gnome-shell/extensions/evil-bit-toggle@jetpham.github.com"
      cp -r . "$out/share/gnome-shell/extensions/evil-bit-toggle@jetpham.github.com"

      runHook postInstall
    '';
  };

  opencodeTokenUsageExtension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-opencode-token-usage";
    version = "1";
    src = ../gnome-extensions/opencode-token-usage;

    installPhase = ''
      runHook preInstall

      substituteInPlace extension.js \
        --replace-fail @opencodeTokenUsage@ ${homeLib.opencodeTokenUsage}

      mkdir -p "$out/share/gnome-shell/extensions/opencode-token-usage@jetpham.github.com"
      cp -r . "$out/share/gnome-shell/extensions/opencode-token-usage@jetpham.github.com"

      runHook postInstall
    '';
  };

  sharedPackages = with pkgs; [
    bat
    bun
    claude-code
    codex
    ffmpeg-full
    homeLib.opencodeDefault
    homeLib.opencodeMine
    homeLib.opencodeOriginal
    skills
    homeLib.zellijNewTabZoxide
    homeLib.zellijSyncTabName
    fd
    btop
    fastfetch
    gh
    hyfetch
    jq
    mkp224o
    nixfmt
    difftastic
    jj-starship
    ripgrep
    tea
    trash-cli
    tree
    unzip

    rust-analyzer
    typescript-language-server
    nil

    file-roller
    font-manager
    (gimp-with-plugins.override {
      plugins = with gimpPlugins; [
        gmic
        resynthesizer
      ];
    })
    google-chrome
    handbrake
    inkscape
    libreoffice
    pavucontrol
    qpwgraph
    lmstudio
    homeLib.betterbird
    brightnessctl
    nautilus
    playerctl
    wl-clipboard
    xprop
    xdg-utils

    gnomeExtensions.auto-move-windows
    gnomeExtensions.appindicator
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.hide-top-bar
    gnomeExtensions.maximized-by-default-actually-reborn
    gnomeExtensions.no-titlebar-when-maximized
    gnomeExtensions.system-monitor-next
    gnomeExtensions.wifi-qrcode
    opencodeTokenUsageExtension
    reducedMotionToggleExtension

    nerd-fonts.commit-mono
  ];

  workPackages = with pkgs; [
    slack
  ];

  personalPackages = with pkgs; [
    element-desktop
    foliate
    kdePackages.kdenlive
    logseq
    nufraw-thumbnailer
    obs-studio
    prismlauncher
    signal-desktop
    vesktop
    vlc
    zulip
    linphone
    darktable
    digikam
    exiftool
    rapid-photo-downloader

    gnomeExtensions.tailscale-qs
    evilBitToggleExtension
  ];
in

{
  home.packages =
    sharedPackages
    ++ pkgs.lib.optionals isWork workPackages
    ++ pkgs.lib.optionals isPersonal personalPackages;
}
