{ lib, pkgs, ... }:

let
  runtimeDeps = with pkgs; [
    coreutils
    cryptsetup
    dbus
    getent
    glibc.bin
    gnugrep
    gnused
    iproute2
    pciutils
    procps
    shadow
    systemd
    util-linux
    xdg-utils
    zfs
  ];

  oneleetAgent = pkgs.stdenv.mkDerivation rec {
    pname = "oneleet-agent";
    version = "2.2.8";

    src = pkgs.fetchurl {
      url = "https://downloads.oneleet.com/agent/linux/agent_${version}_amd64.deb";
      hash = "sha256-daB5mwlBNGx0vTxD4N12WmS/R80seQWt6UKKYy4xyHs=";
    };

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      dpkg
      makeWrapper
    ];

    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libappindicator-gtk3
      libdrm
      libnotify
      libsecret
      libuuid
      libxkbcommon
      mesa
      nspr
      nss
      pango
      stdenv.cc.cc
      udev
      libx11
      libxscrnsaver
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxtst
      libxcb
    ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/opt" "$out/share"
      cp -a opt/Oneleet "$out/opt/"
      cp -a usr/share/. "$out/share/"

      makeWrapper "$out/opt/Oneleet/oneleet-agent" "$out/bin/oneleet-agent" \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}
      makeWrapper "$out/opt/Oneleet/oneleet-daemon" "$out/bin/oneleet-cli" \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}

      substituteInPlace "$out/share/applications/oneleet-agent.desktop" \
        --replace-fail "/opt/Oneleet/oneleet-agent" "$out/bin/oneleet-agent"

      runHook postInstall
    '';

    preFixup = ''
      addAutoPatchelfSearchPath "$out/opt/Oneleet"
    '';

    meta = {
      description = "Oneleet endpoint agent";
      homepage = "https://www.oneleet.com";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };
in

{
  environment.systemPackages = [ oneleetAgent ];

  systemd.tmpfiles.rules = [
    "d /opt 0755 root root -"
    "L+ /opt/Oneleet - - - - ${oneleetAgent}/opt/Oneleet"
    "d /etc/oneleet 0755 root root -"
    "d /var/log/oneleet 0755 root root -"
    "d /var/opt/Oneleet 0755 root root -"

    # Oneleet hardcodes these FHS paths for user/remediation tasks.
    "d /usr/sbin 0755 root root -"
    "d /sbin 0755 root root -"
    "L+ /usr/bin/chage - - - - ${pkgs.shadow}/bin/chage"
    "L+ /usr/bin/getent - - - - ${pkgs.getent}/bin/getent"
    "L+ /usr/sbin/chpasswd - - - - ${pkgs.shadow}/bin/chpasswd"
    "L+ /usr/sbin/useradd - - - - ${pkgs.shadow}/bin/useradd"
    "L+ /usr/sbin/usermod - - - - ${pkgs.shadow}/bin/usermod"
    "L+ /usr/sbin/userdel - - - - ${pkgs.shadow}/bin/userdel"
    "L+ /sbin/shutdown - - - - ${pkgs.systemd}/bin/shutdown"
  ];

  systemd.services.oneleet-daemon = {
    description = "Oneleet Agent Daemon";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "dbus.service"
      "network-online.target"
    ];
    after = [
      "dbus.service"
      "network-online.target"
    ];
    path = runtimeDeps;

    serviceConfig = {
      Type = "simple";
      ExecStart = "${oneleetAgent}/bin/oneleet-cli";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = "/opt/Oneleet";
      LogsDirectory = "oneleet";
    };
  };
}
