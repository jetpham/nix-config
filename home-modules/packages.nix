{
  inputs,
  pkgs,
  homeLib,
  ...
}:

let
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
in

{
  home.packages = with pkgs; [
    bat
    bun
    claude-code
    codex
    ffmpeg-full
    homeLib.wrappedOpencode
    inputs.t3code.packages.${pkgs.stdenv.hostPlatform.system}.t3code-nightly
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
    ripgrep
    tea
    trash-cli
    tree
    unzip

    rust-analyzer
    typescript-language-server
    nil

    element-desktop
    file-roller
    font-manager
    foliate
    (gimp-with-plugins.override {
      plugins = with gimpPlugins; [
        gmic
        resynthesizer
      ];
    })
    google-chrome
    handbrake
    inkscape
    kdePackages.kdenlive
    libreoffice
    logseq
    nufraw-thumbnailer
    obs-studio
    pavucontrol
    prismlauncher
    qpwgraph
    qbittorrent-enhanced
    signal-desktop
    slack
    tor-browser
    vesktop
    vlc
    zulip
    linphone
    lmstudio
    homeLib.betterbird
    darktable
    digikam
    exiftool
    rapid-photo-downloader
    brightnessctl
    nautilus
    playerctl
    wl-clipboard
    xprop
    xdg-utils

    gnomeExtensions.appindicator
    gnomeExtensions.auto-move-windows
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.emoji-copy
    gnomeExtensions.hide-top-bar
    gnomeExtensions.maximized-by-default-actually-reborn
    gnomeExtensions.no-titlebar-when-maximized
    gnomeExtensions.system-monitor-next
    gnomeExtensions.tailscale-qs
    gnomeExtensions.wifi-qrcode
    reducedMotionToggleExtension

    nerd-fonts.commit-mono
  ];
}
