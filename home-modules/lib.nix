{
  config,
  pkgs,
  inputs,
  ...
}:

let
  name = "Jet";
  email = "jet@extremist.software";
  sshSigningKey = "~/.ssh/id_ed25519";
  sshPublicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE40ISu3ydCqfdpb26JYD5cIN0Fu0id/FDS+xjB5zpqu jet@extremist.software"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyic30I+SaDw0Lz/EFpMNeHCwxpwPfkgfR6uz3g7io7 jet@corp.primitive.dev"
  ];
  wrappedOpencode = pkgs.symlinkJoin {
    name = "opencode-wrapped";
    paths = [ pkgs.opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/opencode" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
    '';
  };
  greptileSkills = pkgs.fetchFromGitHub {
    owner = "greptileai";
    repo = "skills";
    rev = "4ae5198fb82fe28d7b452796152f2b1745051c77";
    hash = "sha256-NvDd3BSVeS10kYupLxo27VlKeeHPHrxyTb8EdVqrtQw=";
  };
  betterbird = pkgs.stdenv.mkDerivation rec {
    pname = "betterbird";
    version = "140.10.0esr-bb21";

    src = pkgs.fetchurl {
      url = "https://www.betterbird.eu/downloads/LinuxArchive/betterbird-${version}.en-US.linux-x86_64.tar.xz";
      hash = "sha256-Uh55xWn/cjoIutX2xdM/jUWw9c2As8P4fefK5KQtbQo=";
    };

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
      pkgs.patchelfUnstable
      pkgs.wrapGAppsHook3
    ];

    # Mozilla binaries use relrhack, which breaks if patchelf clobbers sections.
    patchelfFlags = [ "--no-clobber-old-sections" ];

    buildInputs = with pkgs; [
      alsa-lib
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
      gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}")

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

    meta = with pkgs.lib; {
      description = "Betterbird mail client";
      homepage = "https://www.betterbird.eu/";
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      license = licenses.mpl20;
      platforms = [ "x86_64-linux" ];
    };
  };
  betterbirdLauncher = pkgs.writeShellApplication {
    name = "betterbird-profile";
    text = ''
      set -euo pipefail

      profile_root="''${HOME:-${config.home.homeDirectory}}/.thunderbird"
      profile="$profile_root/betterbird-current"

      if [ -d "$profile" ]; then
        exec ${betterbird}/bin/betterbird --profile "$profile" "$@"
      fi

      exec ${betterbird}/bin/betterbird "$@"
    '';
  };
  nasaApodWallpaper = pkgs.writeShellApplication {
    name = "nasa-apod-wallpaper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.sway
    ];
    text = ''
      set -euo pipefail

      state_dir="${config.home.homeDirectory}/.local/state/nasa-apod"
      current_link="$state_dir/current"
      mkdir -p "$state_dir"
      curl_args=(
        --fail
        --silent
        --show-error
        --location
        --retry 30
        --retry-all-errors
        --retry-delay 2
        --connect-timeout 10
        --max-time 300
      )

      set_wallpaper() {
        local target="$1"

        if [ -n "''${SWAYSOCK:-}" ] && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          swaymsg output "*" bg "$target" fill >/dev/null
        fi
      }

      if [ -e "$current_link" ]; then
        set_wallpaper "$current_link"
      fi

      json="$(curl "''${curl_args[@]}" 'https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY' || true)"
      if [ -z "$json" ]; then
        exit 0
      fi

      media_type="$(printf '%s' "$json" | jq -r '.media_type // empty')"

      if [ "$media_type" != "image" ]; then
        exit 0
      fi

      image_url="$(printf '%s' "$json" | jq -r '.hdurl // .url // empty')"
      if [ -z "$image_url" ]; then
        exit 0
      fi

      ext="''${image_url##*.}"
      ext="''${ext%%\?*}"
      if [ -z "$ext" ] || [ "$ext" = "$image_url" ]; then
        ext="jpg"
      fi

      date_stamp="$(printf '%s' "$json" | jq -r '.date // empty')"
      if [ -z "$date_stamp" ]; then
        date_stamp="$(date +%F)"
      fi

      target="$state_dir/apod-$date_stamp.$ext"
      tmp="$target.tmp"

      if curl "''${curl_args[@]}" "$image_url" -o "$tmp" && [ -s "$tmp" ]; then
        mv "$tmp" "$target"
        ln -sfn "$target" "$current_link"
      else
        rm -f "$tmp"
      fi

      if [ -e "$current_link" ]; then
        set_wallpaper "$current_link"
      fi
    '';
  };
  zellijNewTabZoxide = pkgs.writeShellApplication {
    name = "zellij-new-tab-zoxide";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.fzf
      pkgs.zellij
      pkgs.zoxide
    ];
    text = ''
      set -euo pipefail

      dirs="$(${pkgs.zoxide}/bin/zoxide query -l | while IFS= read -r dir; do
        if [ -d "$dir" ]; then
          printf '%s\t%s\n' "$(${pkgs.coreutils}/bin/basename "$dir")" "$dir"
        fi
      done)"

      if [ -z "$dirs" ]; then
        if [ -n "''${ZELLIJ:-}" ]; then
          exec ${pkgs.bashInteractive}/bin/bash -i
        fi
        exit 1
      fi

      dir="$(printf '%s\n' "$dirs" | ${pkgs.fzf}/bin/fzf \
        --delimiter='\t' \
        --with-nth='2' \
        --nth='1' \
        --height='40%' \
        --layout='reverse' \
        --border \
        --prompt='dir> ' \
        --exit-0 | ${pkgs.coreutils}/bin/cut -f2-)"

      if [ -z "$dir" ]; then
        if [ -n "''${ZELLIJ:-}" ]; then
          ${pkgs.zellij}/bin/zellij action close-tab >/dev/null 2>&1 || true
          exit 0
        fi
        exit 1
      fi

      tab_name="$(${pkgs.coreutils}/bin/basename "$dir")"
      if [ "$dir" = "/" ]; then
        tab_name="/"
      fi

      cd "$dir"

      escape_kdl() {
        local value="$1"
        value="''${value//\\/\\\\}"
        value="''${value//\"/\\\"}"
        printf '%s' "$value"
      }

      if [ -n "''${ZELLIJ:-}" ]; then
        ${pkgs.zellij}/bin/zellij action rename-tab "$tab_name" >/dev/null 2>&1 || true
      fi

      if [ -n "''${ZELLIJ:-}" ]; then
        exec ${pkgs.bashInteractive}/bin/bash -i
      fi

      layout_file="${config.home.homeDirectory}/.local/state/zellij-launch-layout.kdl"
      mkdir -p "$(dirname "$layout_file")"
      printf '%s\n' \
        'layout {' \
        "  tab name=\"$(escape_kdl "$tab_name")\" cwd=\"$(escape_kdl "$dir")\" {" \
        '    pane focus=true' \
        '    pane size=1 borderless=true {' \
        '      plugin location="compact-bar"' \
        '    }' \
        '  }' \
        '}' > "$layout_file"

      exec ${pkgs.zellij}/bin/zellij -l "$layout_file"
    '';
  };
  zellijPersistentSession = pkgs.writeShellApplication {
    name = "zellij-persistent-session";
    runtimeInputs = [ pkgs.zellij ];
    text = ''
      set -euo pipefail

      while true; do
        if ${pkgs.zellij}/bin/zellij attach --create main --force-run-commands; then
          if ! ${zellijNewTabZoxide}/bin/zellij-new-tab-zoxide; then
            exec ${pkgs.bashInteractive}/bin/bash -i
          fi
        else
          exit $?
        fi
      done
    '';
  };
  zellijSyncTabName = pkgs.writeShellApplication {
    name = "zellij-sync-tab-name";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.zellij
    ];
    text = ''
      set -euo pipefail

      if [ -z "''${ZELLIJ:-}" ]; then
        exit 0
      fi

      current_tab_info="$(${pkgs.zellij}/bin/zellij action current-tab-info --json 2>/dev/null)"
      current_tab_id="$(printf '%s\n' "$current_tab_info" | ${pkgs.jq}/bin/jq -r '.tab_id // empty')"
      current_tab_name="$(printf '%s\n' "$current_tab_info" | ${pkgs.jq}/bin/jq -r '.name // empty')"

      if [ -z "$current_tab_id" ]; then
        exit 0
      fi

      next_tab_name="$(${pkgs.zellij}/bin/zellij action list-panes --json 2>/dev/null | ${pkgs.jq}/bin/jq -r --argjson tab_id "$current_tab_id" '
        [ .[]
          | select((.is_plugin | not) and .tab_id == $tab_id)
          | .pane_cwd // empty
          | if . == "/" then "/" else split("/") | map(select(length > 0)) | last end
        ]
        | reduce .[] as $name ([]; if index($name) == null then . + [$name] else . end)
        | join("-")
      ' 2>/dev/null)"

      if [ -z "$next_tab_name" ] || [ "$next_tab_name" = "$current_tab_name" ]; then
        exit 0
      fi

      exec ${pkgs.zellij}/bin/zellij action rename-tab "$next_tab_name"
    '';
  };
  zenStartup = pkgs.makeDesktopItem {
    name = "zen-startup";
    desktopName = "Zen Startup";
    comment = "Launch Zen Browser";
    exec = "${config.programs.zen-browser.package}/bin/zen-beta";
    terminal = false;
    noDisplay = true;
    categories = [ "Network" ];
  };
  ghosttyZellijStartup = pkgs.makeDesktopItem {
    name = "ghostty-zellij-startup";
    desktopName = "Ghostty Zellij Startup";
    comment = "Open Ghostty and attach to the main Zellij session";
    exec = "${pkgs.ghostty}/bin/ghostty --fullscreen=true -e ${zellijPersistentSession}/bin/zellij-persistent-session";
    terminal = false;
    noDisplay = true;
    categories = [
      "TerminalEmulator"
    ];
  };
  vesktopStartup = pkgs.makeDesktopItem {
    name = "vesktop-startup";
    desktopName = "Vesktop Startup";
    comment = "Launch Vesktop in fullscreen";
    exec = "${pkgs.vesktop}/bin/vesktop --start-fullscreen";
    terminal = false;
    noDisplay = true;
    categories = [ "Network" ];
  };
  signalStartup = pkgs.makeDesktopItem {
    name = "signal-startup";
    desktopName = "Signal Startup";
    comment = "Launch Signal in fullscreen";
    exec = "${pkgs.signal-desktop}/bin/signal-desktop --start-fullscreen";
    terminal = false;
    noDisplay = true;
    categories = [ "Network" ];
  };
  betterbirdStartup = pkgs.makeDesktopItem {
    name = "betterbird-startup";
    desktopName = "Betterbird Startup";
    comment = "Launch Betterbird in fullscreen";
    exec = "${betterbirdLauncher}/bin/betterbird-profile";
    terminal = false;
    noDisplay = true;
    categories = [ "Network" ];
  };
  zulipStartup = pkgs.makeDesktopItem {
    name = "zulip-startup";
    desktopName = "Zulip Startup";
    comment = "Launch Zulip in fullscreen";
    exec = "${pkgs.zulip}/bin/zulip --start-fullscreen";
    terminal = false;
    noDisplay = true;
    categories = [ "Network" ];
  };
in
{
  _module.args.homeLib = {
    inherit
      betterbirdStartup
      betterbird
      betterbirdLauncher
      email
      ghosttyZellijStartup
      greptileSkills
      name
      nasaApodWallpaper
      signalStartup
      sshPublicKeys
      sshSigningKey
      wrappedOpencode
      zenStartup
      zellijNewTabZoxide
      zellijPersistentSession
      zellijSyncTabName
      zulipStartup
      vesktopStartup
      ;
  };
}
