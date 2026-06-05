{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  cups,
  dbus-glib,
  fetchurl,
  gdk-pixbuf,
  glib,
  gtk3,
  lib,
  libGL,
  libdrm,
  libice,
  libnotify,
  libpulseaudio,
  libsm,
  libstartup_notification,
  libva,
  libx11,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxt,
  libxtst,
  makeWrapper,
  mesa,
  nspr,
  nss,
  pango,
  patchelfUnstable,
  pciutils,
  stdenv,
  udev,
  wrapGAppsHook3,
}:

stdenv.mkDerivation rec {
  pname = "betterbird";
  version = "140.11.0esr-bb23";

  src = fetchurl {
    urls = [
      "https://www.betterbird.eu/downloads/LinuxArchive/betterbird-${version}.en-US.linux-x86_64.tar.xz"
      "https://www.betterbird.eu/downloads/LinuxArchive/Previous/betterbird-${version}.en-US.linux-x86_64.tar.xz"
    ];
    hash = "sha256-f5feH3Yj1XsKTaKJyEGJ3zASrwKTulFNDoowtaLYSyU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    patchelfUnstable
    wrapGAppsHook3
  ];

  patchelfFlags = [ "--no-clobber-old-sections" ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus-glib
    gdk-pixbuf
    glib
    gtk3
    libGL
    libdrm
    libnotify
    libpulseaudio
    libstartup_notification
    libva
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pciutils
    udev
    libice
    libsm
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxt
    libxtst
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib" "$out/bin" "$out/share"
    cp -r betterbird "$out/lib/betterbird"

    ln -s "$out/lib/betterbird/betterbird" "$out/bin/betterbird"

    gappsWrapperArgs+=(--argv0 "$out/bin/.betterbird-wrapped")
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}")

    if [ -d "$out/lib/betterbird/chrome/icons/default" ]; then
      mkdir -p "$out/share/icons/hicolor/128x128/apps"
      cp "$out/lib/betterbird/chrome/icons/default/default128.png" "$out/share/icons/hicolor/128x128/apps/betterbird.png"
    fi

    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/betterbird.desktop" <<EOF
    [Desktop Entry]
    Name=Betterbird
    Comment=Mail, RSS and newsgroups client
    Exec=$out/bin/betterbird %u
    Terminal=false
    Type=Application
    Icon=betterbird
    Categories=Network;Email;
    MimeType=x-scheme-handler/mailto;message/rfc822;x-scheme-handler/webcal;x-scheme-handler/webcals;
    StartupNotify=false
    StartupWMClass=eu.betterbird.Betterbird
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Betterbird mail client";
    homepage = "https://www.betterbird.eu/";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    license = licenses.mpl20;
    platforms = [ "x86_64-linux" ];
  };
}
