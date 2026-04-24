{ pkgs, homeLib, ... }:

{
  home.packages = with pkgs; [
    bat
    bun
    claude-code
    codex
    ffmpeg-full
    homeLib.wrappedOpencode
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
    gimp3
    google-chrome
    handbrake
    inkscape
    kdePackages.kdenlive
    libreoffice
    logseq
    obs-studio
    pavucontrol
    prismlauncher
    qpwgraph
    qbittorrent-enhanced
    signal-desktop
    slack
    t3code
    tor-browser
    vesktop
    vlc
    zulip
    linphone
    lmstudio
    homeLib.betterbird

    nerd-fonts.commit-mono

    gnomeExtensions.clipboard-indicator
    gnomeExtensions.emoji-copy
    gnomeExtensions.hide-top-bar
    gnomeExtensions.system-monitor-next
    gnomeExtensions.wifi-qrcode
  ];
}
