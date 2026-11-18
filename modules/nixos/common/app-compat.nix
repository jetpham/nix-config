{ pkgs, ... }:

{
  # T3 downloads Chrome Headless Shell as an upstream Linux binary.
  # nix-ld supplies its loader and libraries without modifying the download.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      systemd
      vulkan-loader
    ];
  };

  systemd.tmpfiles.rules = [
    "L+ /usr/bin/bwrap - - - - ${pkgs.bubblewrap}/bin/bwrap"
  ];

  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
