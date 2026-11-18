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
      pkgs.curl
      pkgs.glib
      (pkgs.python3.withPackages (ps: [ ps.pillow ]))
    ];
    text = ''
      exec python3 ${./scripts/nasa-apod-wallpaper.py} "${config.home.homeDirectory}/.local/state/nasa-apod"
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
  t3codeStartup = pkgs.makeDesktopItem {
    name = "t3code-startup";
    desktopName = "T3 Code Startup";
    comment = "Launch T3 Code";
    exec = "${pkgs.t3code}/bin/t3code-desktop";
    terminal = false;
    noDisplay = true;
    categories = [ "Development" ];
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
  zulipLauncher = pkgs.writeShellApplication {
    name = "zulip-fullscreen";
    text = ''
      # Zulip restores electron-window-state rather than honoring --start-fullscreen.
      ${pkgs.python3}/bin/python3 - <<'PY'
      import json
      import os
      from pathlib import Path
      import tempfile

      config_root = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
      state_path = config_root / "Zulip/config/window-state.json"
      state_path.parent.mkdir(parents=True, exist_ok=True)
      state = json.loads(state_path.read_text()) if state_path.exists() else {}
      state["isFullScreen"] = True
      with tempfile.NamedTemporaryFile(mode="w", dir=state_path.parent, delete=False) as output:
          json.dump(state, output)
          temporary_path = output.name
      os.replace(temporary_path, state_path)
      PY
      exec ${pkgs.zulip}/bin/zulip "$@"
    '';
  };
  zulipStartup = pkgs.makeDesktopItem {
    name = "zulip-startup";
    desktopName = "Zulip Startup";
    comment = "Launch Zulip in fullscreen";
    exec = "${zulipLauncher}/bin/zulip-fullscreen";
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
      ghosttyLaunchCommand
      ghosttyLocalLauncher
      ghosttyZellijLauncher
      ghosttyZellijStartup
      greptileSkills
      inthAgentSkills
      name
      nasaApodWallpaper
      signalStartup
      sshPublicKeys
      sshSigningKey
      t3codeStartup
      zenStartup
      zellijNewTabZoxide
      zellijPersistentSession
      zellijSyncTabName
      zulipStartup
      zulipLauncher
      vesktopStartup
      ;
  };
}
