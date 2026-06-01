{
  config,
  pkgs,
  inputs,
  hostname,
  ...
}:

let
  sshPublicKeys = (import ../ssh-public-keys.nix).jet;
  name = "Jet";
  email = if hostname == "framework-work" then "jet@corp.primitive.dev" else "jet@extremist.software";
  sshSigningKey = "~/.ssh/id_ed25519";
  opencodeLibraryPath = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
  opencodeMine = pkgs.writeShellApplication {
    name = "o";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      export OPENCODE_DB=opencode.db
      export LD_LIBRARY_PATH="${opencodeLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

      if [ "$#" -eq 0 ] && curl \
        --fail \
        --silent \
        --connect-timeout 0.2 \
        --max-time 0.5 \
        --output /dev/null \
        http://127.0.0.1:4096/global/health; then
        exec ${pkgs.opencode}/bin/opencode attach http://127.0.0.1:4096 --dir "$PWD"
      fi

      exec ${pkgs.opencode}/bin/opencode "$@"
    '';
  };
  opencodeDefault = pkgs.writeShellApplication {
    name = "opencode";
    text = ''
      export OPENCODE_DB=opencode.db
      export LD_LIBRARY_PATH="${opencodeLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec ${pkgs.opencode}/bin/opencode "$@"
    '';
  };
  opencodeOriginal = pkgs.writeShellApplication {
    name = "oo";
    text = ''
      export OPENCODE_DB=opencode.db
      export LD_LIBRARY_PATH="${opencodeLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec ${pkgs.opencode-original}/bin/opencode "$@"
    '';
  };
  opencodeTokenUsage = pkgs.writeShellApplication {
    name = "opencode-token-usage";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.jq
      pkgs.sqlite
    ];
    text = ''
      set -euo pipefail

      data_home="''${XDG_DATA_HOME:-''${HOME}/.local/share}"
      db_specs="''${OPENCODE_DBS:-opencode.db}"
      plan_usd="''${CHATGPT_PLAN_USD:-200}"

      read -r -a db_spec_array <<< "$db_specs"
      dbs=()
      missing_dbs=()
      db_summary=""
      missing_summary=""
      for db_spec in "''${db_spec_array[@]}"; do
        case "$db_spec" in
          /*) db="$db_spec" ;;
          *) db="$data_home/opencode/$db_spec" ;;
        esac

        if [ -r "$db" ]; then
          dbs+=("$db")
          db_name="''${db##*/}"
          if [ -n "$db_summary" ]; then
            db_summary="$db_summary, $db_name"
          else
            db_summary="$db_name"
          fi
        else
          missing_dbs+=("$db")
          db_name="''${db##*/}"
          if [ -n "$missing_summary" ]; then
            missing_summary="$missing_summary, $db_name"
          else
            missing_summary="$db_name"
          fi
        fi
      done

      if [ "''${#dbs[@]}" -eq 0 ]; then
        jq -cn --arg text "tok 0" --arg tooltip "OpenCode token DBs not found: $missing_summary" '{ text: $text, value: "0", values: [], tooltip: $tooltip, class: "missing" }'
        exit 0
      fi

      now_ms=$(( $(date +%s) * 1000 ))
      start_ms=$(( $(date -d 'today 00:00' +%s) * 1000 ))

      sessions=0
      input=0
      output=0
      reasoning=0
      cache_read=0
      cache_write=0
      for db in "''${dbs[@]}"; do
        row=$(sqlite3 -separator '|' "$db" "
        SELECT
          COUNT(*),
          COALESCE(SUM(tokens_input), 0),
          COALESCE(SUM(tokens_output), 0),
          COALESCE(SUM(tokens_reasoning), 0),
          COALESCE(SUM(tokens_cache_read), 0),
          COALESCE(SUM(tokens_cache_write), 0)
        FROM session
        WHERE time_created >= $start_ms;
        ")
        IFS='|' read -r db_sessions db_input db_output db_reasoning db_cache_read db_cache_write <<< "$row"
        sessions=$(( sessions + db_sessions ))
        input=$(( input + db_input ))
        output=$(( output + db_output ))
        reasoning=$(( reasoning + db_reasoning ))
        cache_read=$(( cache_read + db_cache_read ))
        cache_write=$(( cache_write + db_cache_write ))
      done

      billable=$(( input + output + reasoning ))
      with_cache=$(( billable + cache_read + cache_write ))
      cost=$(awk -v input="$input" -v output="$output" -v reasoning="$reasoning" -v cache_read="$cache_read" -v cache_write="$cache_write" 'BEGIN { printf "%.2f", (input * 0.25 + (output + reasoning) * 2.00 + cache_read * 0.025 + cache_write * 0.25) / 1000000 }')
      plan_pct=$(awk -v cost="$cost" -v plan="$plan_usd" 'BEGIN { if (plan > 0) printf "%.1f", cost / plan * 100; else printf "0.0" }')

      short_tokens() {
        awk -v n="$1" 'BEGIN { if (n >= 1000000000) printf "%.1fB", n / 1000000000; else if (n >= 1000000) printf "%.1fM", n / 1000000; else if (n >= 1000) printf "%.1fk", n / 1000; else printf "%d", n }'
      }

      graph=()
      for ((i = 0; i < 24; i++)); do
        graph[i]=0
      done
      for db in "''${dbs[@]}"; do
        values=$(sqlite3 -separator '|' -noheader "$db" "
        WITH RECURSIVE buckets(start_ms, stop_ms, i) AS (
          SELECT (($now_ms / 3600000) - 23) * 3600000, (($now_ms / 3600000) - 22) * 3600000, 0
          UNION ALL
          SELECT start_ms + 3600000, stop_ms + 3600000, i + 1 FROM buckets WHERE i < 23
        )
        SELECT buckets.i, COALESCE(SUM(COALESCE(tokens_input, 0) + COALESCE(tokens_output, 0) + COALESCE(tokens_reasoning, 0)), 0)
        FROM buckets
        LEFT JOIN session ON session.time_created >= buckets.start_ms AND session.time_created < buckets.stop_ms
        GROUP BY buckets.i
        ORDER BY buckets.i;
        ")
        while IFS='|' read -r index value; do
          if [ -n "$index" ]; then
            graph[index]=$(( graph[index] + value ))
          fi
        done <<< "$values"
      done
      graph_values=$(printf '%s\n' "''${graph[@]}" | jq -Rcs 'split("\n") | map(select(length > 0) | tonumber)')
      billable_short=$(short_tokens "$billable")
      text="tok $billable_short"
      tooltip=$(printf 'OpenCode tokens today\nSources: %s\nGraph: last 24 hourly billable-token buckets\nSessions: %s\nBillable excl. cache: %s\nIncluding cache reads: %s\nInput: %s\nOutput: %s\nReasoning: %s\nCache read: %s\nEstimated GPT-5.5 Fast cost: $%s (%s%% of $%s)\nChatGPT plan limits: not exposed locally; this is an API-equivalent estimate.' "$db_summary" "$sessions" "$billable" "$with_cache" "$input" "$output" "$reasoning" "$cache_read" "$cost" "$plan_pct" "$plan_usd")
      if [ "''${#missing_dbs[@]}" -gt 0 ]; then
        tooltip=$(printf '%s\nMissing sources: %s' "$tooltip" "$missing_summary")
      fi
      class=$(awk -v pct="$plan_pct" 'BEGIN { if (pct >= 80) print "critical"; else if (pct >= 50) print "warning"; else print "normal" }')

      jq -cn --arg text "$text" --arg value "$billable_short" --arg tooltip "$tooltip" --arg class "$class" --argjson values "$graph_values" '{ text: $text, value: $value, values: $values, tooltip: $tooltip, class: $class }'
    '';
  };
  greptileSkills = pkgs.fetchFromGitHub {
    owner = "greptileai";
    repo = "skills";
    rev = "bda66cce07d1c59c83d387b87aeeed042b13369d";
    hash = "sha256-yfzi1K+Ko4YOpWYC5a+GCndtKkNsyRBhhns+KJU/f+E=";
  };
  inthAgentSkills = pkgs.fetchFromGitHub {
    owner = "inthhq";
    repo = "agent-skills";
    rev = "ffcbc99bc3d8a72deb5659c18a2ccdfaf416fc1c";
    hash = "sha256-as2+FYIohxwcwFiaucJ6heFtZmDlA4l1jVXUU9wh5SQ=";
  };
  betterbird = pkgs.stdenv.mkDerivation rec {
    pname = "betterbird";
    version = "140.11.0esr-bb23";

    src = pkgs.fetchurl {
      urls = [
        "https://www.betterbird.eu/downloads/LinuxArchive/betterbird-${version}.en-US.linux-x86_64.tar.xz"
        "https://www.betterbird.eu/downloads/LinuxArchive/Previous/betterbird-${version}.en-US.linux-x86_64.tar.xz"
      ];
      hash = "sha256-f5feH3Yj1XsKTaKJyEGJ3zASrwKTulFNDoowtaLYSyU=";
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

      if [ ! -d "$profile" ]; then
        echo "Betterbird profile not found: $profile" >&2
        exit 1
      fi

      exec ${betterbird}/bin/betterbird --profile "$profile" "$@"
    '';
  };
  nasaApodWallpaper = pkgs.writeShellApplication {
    name = "nasa-apod-wallpaper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.glib
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      state_dir="${config.home.homeDirectory}/.local/state/nasa-apod"
      current_link="$state_dir/current"
      mkdir -p "$state_dir"

      read_api_key_file() {
        local key_file="$1"

        if [ -r "$key_file" ]; then
          while IFS= read -r line; do
            case "$line" in
              NASA_API_KEY=*)
                api_key="''${line#NASA_API_KEY=}"
                ;;
            esac
          done < "$key_file"
        fi
      }

      api_key="''${NASA_API_KEY:-}"
      if [ -z "$api_key" ]; then
        read_api_key_file "''${NASA_API_KEY_FILE:-${config.home.homeDirectory}/.config/nasa-api.env}"
      fi
      if [ -z "$api_key" ]; then
        exit 0
      fi

      api_curl_args=(
        --fail
        --silent
        --show-error
        --location
        --connect-timeout 5
        --max-time 20
      )

      image_curl_args=(
        --fail
        --silent
        --show-error
        --location
        --retry 2
        --retry-delay 5
        --retry-max-time 120
        --connect-timeout 10
        --max-time 60
      )

      set_wallpaper() {
        local target="$1"

        if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
          gsettings set org.gnome.desktop.background picture-uri "file://$target"
          gsettings set org.gnome.desktop.background picture-uri-dark "file://$target"
          gsettings set org.gnome.desktop.background picture-options 'zoom'
        fi
      }

      if [ -e "$current_link" ]; then
        set_wallpaper "$current_link"
      fi

      today="$(date +%F)"
      for cached in "$state_dir/apod-$today".*; do
        if [ -s "$cached" ]; then
          ln -sfn "$cached" "$current_link"
          set_wallpaper "$current_link"
          exit 0
        fi
      done

      api_request="$(mktemp)"
      trap 'rm -f "$api_request"' EXIT
      {
        printf '%s\n' 'url = "https://api.nasa.gov/planetary/apod"'
        printf '%s\n' 'get'
        printf 'data-urlencode = "api_key=%s"\n' "$api_key"
        printf '%s\n' 'data-urlencode = "thumbs=True"'
      } > "$api_request"
      chmod 0600 "$api_request"

      json="$(curl "''${api_curl_args[@]}" --config "$api_request" || true)"
      if [ -z "$json" ]; then
        exit 0
      fi

      media_type="$(printf '%s' "$json" | jq -r '.media_type // empty')"
      case "$media_type" in
        image)
          image_url="$(printf '%s' "$json" | jq -r '.hdurl // .url // empty')"
          ;;
        video)
          image_url="$(printf '%s' "$json" | jq -r '.thumbnail_url // empty')"
          ;;
        *)
          exit 0
          ;;
      esac
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

      if [ ! -s "$target" ]; then
        if curl "''${image_curl_args[@]}" "$image_url" -o "$tmp" && [ -s "$tmp" ]; then
          mv "$tmp" "$target"
        else
          rm -f "$tmp"
        fi
      fi

      if [ -e "$target" ]; then
        ln -sfn "$target" "$current_link"
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
      inthAgentSkills
      name
      nasaApodWallpaper
      opencodeDefault
      opencodeMine
      opencodeOriginal
      opencodeTokenUsage
      signalStartup
      sshPublicKeys
      sshSigningKey
      zenStartup
      zellijNewTabZoxide
      zellijPersistentSession
      zellijSyncTabName
      zulipStartup
      vesktopStartup
      ;
  };
}
