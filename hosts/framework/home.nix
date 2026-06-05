{ homePackages, pkgs, ... }:

{
  imports = [
    ../../modules/home/common
    ./home-qbittorrent.nix
    ./home-tor-browser.nix
  ];

  home.packages = with pkgs; [
    darktable
    digikam
    element-desktop
    exiftool
    foliate
    kdePackages.kdenlive
    linphone
    logseq
    mkp224o
    nufraw-thumbnailer
    obs-studio
    prismlauncher
    rapid-photo-downloader
    signal-desktop
    vesktop
    vlc
    zulip

    gnomeExtensions.tailscale-qs
    homePackages.evilBitToggleExtension
  ];

  programs.bash.shellAliases.vanity = "mkp224o-amd64-64-24k -d noisebridgevanitytor noisebridge{2..7}";
}
