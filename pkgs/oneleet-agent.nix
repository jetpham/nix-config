{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  coreutils,
  cryptsetup,
  cups,
  dbus,
  dpkg,
  expat,
  fetchurl,
  gdk-pixbuf,
  getent,
  glib,
  glibc,
  gnugrep,
  gnused,
  gtk3,
  iproute2,
  lib,
  libappindicator-gtk3,
  libdrm,
  libnotify,
  libsecret,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxtst,
  makeWrapper,
  mesa,
  nspr,
  nss,
  pango,
  pciutils,
  procps,
  shadow,
  stdenv,
  systemd,
  udev,
  util-linux,
  xdg-utils,
  zfs,
}:

let
  runtimeDeps = [
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
in
stdenv.mkDerivation rec {
  pname = "oneleet-agent";
  version = "2.2.8";

  src = fetchurl {
    url = "https://downloads.oneleet.com/agent/linux/agent_${version}_amd64.deb";
    hash = "sha256-daB5mwlBNGx0vTxD4N12WmS/R80seQWt6UKKYy4xyHs=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
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

  passthru.runtimeDeps = runtimeDeps;

  meta = {
    description = "Oneleet endpoint agent";
    homepage = "https://www.oneleet.com";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
