{
  config,
  pkgs,
  inputs,
  ...
}:

let
  sshPublicKeys = (import ../../../ssh-public-keys.nix).jet;
  name = "Jet";
  email = "jet@extremist.software";
  sshSigningKey = "~/.ssh/id_ed25519";
  opencodeTailnetUrl = pkgs.writeShellApplication {
    name = "opencode-tailnet-url";
    runtimeInputs = [ pkgs.qrencode ];
    text = ''
      set -euo pipefail

      url="https://framework.taile9e84e.ts.net"

      usage() {
        printf 'Usage: opencode-tailnet-url [--qr]\n' >&2
        exit 64
      }

      case "''${1:-}" in
        "")
          printf '%s\n' "$url"
          ;;
        --qr)
          qrencode -t UTF8 "$url"
          ;;
        *)
          usage
          ;;
      esac
    '';
  };
  opencodeLocal = pkgs.writeShellApplication {
    name = "opencode-local";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      set -euo pipefail

      server="''${OPENCODE_LOCAL_SERVER:-http://127.0.0.1:4096}"
      server="''${server%/}"
      dir="''${OPENCODE_LOCAL_DIR:-$PWD}"

      if ! curl --fail --silent --show-error --max-time 5 "$server/global/health" >/dev/null; then
        printf 'Local opencode server is not responding: %s\n' "$server" >&2
        exit 1
      fi

      exec ${pkgs.opencode}/bin/opencode attach "$server" --dir "$dir" "$@"
    '';
  };
  opencodeDevbox = pkgs.writeShellApplication {
    name = "opencode-devbox";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      set -euo pipefail

      server="''${OPENCODE_DEVBOX_SERVER:-https://devbox.taile9e84e.ts.net}"
      server="''${server%/}"
      dir="''${OPENCODE_DEVBOX_DIR:-/home/jet/dev}"

      if ! curl --fail --silent --show-error --max-time 10 "$server/global/health" >/dev/null; then
        printf 'Devbox opencode server is not responding: %s\n' "$server" >&2
        exit 1
      fi

      exec ${pkgs.opencode}/bin/opencode attach "$server" --dir "$dir" "$@"
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
  betterbird = pkgs.betterbird;
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

      exec ${pkgs.zellij}/bin/zellij attach --create main
    '';
  };
  ghosttyLaunchCommand = "${pkgs.ghostty}/bin/ghostty --gtk-single-instance=true";
  ghosttyZellijLauncher = pkgs.writeShellApplication {
    name = "ghostty-zellij";
    text = ''
      exec ${ghosttyLaunchCommand} "$@"
    '';
  };
  ghosttyLocalLauncher = pkgs.writeShellApplication {
    name = "ghostty-local";
    text = ''
      exec ${ghosttyLaunchCommand} "$@"
    '';
  };
  devboxLauncher = pkgs.writeShellApplication {
    name = "devbox";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssh
    ];
    text = ''
      set -euo pipefail

      exec ${ghosttyLaunchCommand} -e ${pkgs.coreutils}/bin/env TERM=xterm-256color ${pkgs.openssh}/bin/ssh \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -tt jet@devbox.taile9e84e.ts.net \
        'zellij attach --create main'
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
    exec = "${ghosttyZellijLauncher}/bin/ghostty-zellij";
    terminal = false;
    noDisplay = true;
    categories = [
      "System"
      "TerminalEmulator"
    ];
  };
  devboxDesktop = pkgs.makeDesktopItem {
    name = "devbox";
    desktopName = "devbox";
    comment = "Open devbox remote Zellij in Ghostty";
    exec = "${devboxLauncher}/bin/devbox";
    icon = "com.mitchellh.ghostty";
    terminal = false;
    categories = [
      "System"
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
      devboxDesktop
      devboxLauncher
      email
      ghosttyLaunchCommand
      ghosttyLocalLauncher
      ghosttyZellijLauncher
      ghosttyZellijStartup
      greptileSkills
      inthAgentSkills
      name
      nasaApodWallpaper
      opencodeDevbox
      opencodeLocal
      opencodeTailnetUrl
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
