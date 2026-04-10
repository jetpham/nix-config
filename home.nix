{
  config,
  pkgs,
  inputs,
  ...
}:

let
  name = "Jet";
  email = "jet@extremist.software";
  sshSigningKey = "~/.ssh/id_ed25519.pub";
  zenStartup = pkgs.makeDesktopItem {
    name = "zen-startup";
    desktopName = "Zen Startup";
    comment = "Launch Zen Browser";
    exec = "${config.programs.zen-browser.package}/bin/zen-beta";
    terminal = false;
    categories = [ "Network" ];
  };
  kittyZellijStartup = pkgs.makeDesktopItem {
    name = "kitty-zellij-startup";
    desktopName = "Kitty Zellij Startup";
    comment = "Open Kitty and attach to the main Zellij session";
    exec = "${pkgs.kitty}/bin/kitty --start-as=fullscreen ${zellijPersistentSession}/bin/zellij-persistent-session";
    terminal = false;
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
    categories = [ "Network" ];
  };
  signalStartup = pkgs.makeDesktopItem {
    name = "signal-startup";
    desktopName = "Signal Startup";
    comment = "Launch Signal in fullscreen";
    exec = "${pkgs.signal-desktop}/bin/signal-desktop --start-fullscreen";
    terminal = false;
    categories = [ "Network" ];
  };
  betterbirdStartup = pkgs.makeDesktopItem {
    name = "betterbird-startup";
    desktopName = "Betterbird Startup";
    comment = "Launch Betterbird in fullscreen";
    exec = "${pkgs.flatpak}/bin/flatpak run eu.betterbird.Betterbird --fullscreen";
    terminal = false;
    categories = [ "Network" ];
  };
  zulipStartup = pkgs.makeDesktopItem {
    name = "zulip-startup";
    desktopName = "Zulip Startup";
    comment = "Launch Zulip in fullscreen";
    exec = "${pkgs.zulip}/bin/zulip --start-fullscreen";
    terminal = false;
    categories = [ "Network" ];
  };
  tailscaleQsExtension = pkgs.stdenvNoCC.mkDerivation {
    pname = "tailscale-gnome-qs";
    version = "5";
    src = pkgs.fetchzip {
      url = "https://github.com/tailscale-qs/tailscale-gnome-qs/archive/refs/tags/v5.tar.gz";
      sha256 = "0b9jy8pyxvpkxf3adlwq42kii14jn5g7xyxggjzg87pb5jg4zfg2";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p "$out/share/gnome-shell/extensions"
      cp -r "$src/tailscale-gnome-qs@tailscale-qs.github.io" \
        "$out/share/gnome-shell/extensions/tailscale-gnome-qs@tailscale-qs.github.io"
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

        gsettings set org.gnome.desktop.background picture-uri "file://$target"
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$target"
        gsettings set org.gnome.desktop.background picture-options 'zoom'
      }

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
        set_wallpaper "$target"
      else
        rm -f "$tmp"
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
in
{
  imports = [ inputs.zen-browser.homeModules.default ];

  home.username = "jet";
  home.homeDirectory = "/home/jet";
  home.stateVersion = "25.05";

  # Configure GNOME settings
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      clock-format = "12h";
      clock-show-weekday = true;
      color-scheme = "prefer-dark";
      enable-animations = false;
      enable-hot-corners = false;
    };
    "org/gnome/system/location" = {
      enabled = true;
    };
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
    };
    "org/gtk/settings/file-chooser" = {
      clock-format = "12h";
      show-hidden = true;
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      disable-while-typing = false;
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "hidetopbar@mathieu.bidon.ca"
        "wifiqrcode@glerro.pm.me"
        "system-monitor@paradoxxx.zero.gmail.com"
        "clipboard-indicator@tudmotu.com"
        "emoji-copy@felipeftn"
        "tailscale-gnome-qs@tailscale-qs.github.io"
      ];
    };
  };

  home.packages = with pkgs; [
    # Scripts
    (writeShellScriptBin "tea-init" ''
      name="''${1:-$(basename "$PWD")}"
      login="''${2:-git.extremist.software}"
      user=$(tea logins list -o simple | awk -v l="$login" '$2 == "https://"l {print $4}')
      if [ -z "$user" ]; then
        echo "error: no tea login found for $login" >&2
        exit 1
      fi
      tea repo create --name "$name" --login "$login"
      git remote add origin "ssh://forgejo@''${login}/''${user}/''${name}.git"
    '')
    (writeShellScriptBin "ow" ''
      sudo -v
      sudo tailscale serve --bg 4096
      exec opencode web --hostname 127.0.0.1 --port 4096
    '')

    # CLI
    bat
    ffmpeg-full
    opencode
    zellijNewTabZoxide
    zellijSyncTabName
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

    # LSP Servers
    rust-analyzer
    typescript-language-server
    nil

    # Desktop
    element-desktop
    file-roller
    font-manager
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
    tor-browser
    vesktop
    vlc
    zulip
    linphone
    lmstudio

    # Fonts
    nerd-fonts.commit-mono

    # GNOME Extensions
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.emoji-copy
    gnomeExtensions.hide-top-bar
    gnomeExtensions.system-monitor-next
    gnomeExtensions.wifi-qrcode
  ];

  home.sessionVariables = {
    BROWSER = "zen";
    TERMINAL = "kitty";
  };

  programs.git = {
    enable = true;
    settings.user.name = name;
    settings.user.email = email;
    signing = {
      key = sshSigningKey;
      signByDefault = true;
      format = "ssh";
    };
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "dark_high_contrast";
      editor = {
        line-number = "relative";
        lsp.display-messages = true;
        lsp.display-inlay-hints = true;
        end-of-line-diagnostics = "hint";
        inline-diagnostics = {
          cursor-line = "hint";
          other-lines = "hint";
        };
      };
    };
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      format = "$directory$git_status$nix_shell$cmd_duration$line_break$character";
      directory.truncation_length = 3;
      git_status.style = "red";
      git_branch.disabled = true;
      nix_shell.format = "[$symbol]($style) ";
      cmd_duration.min_time = 500;
      character.success_symbol = "[❯](bold green)";
      character.error_symbol = "[❯](bold red)";
    };
  };

  programs.zellij = {
    enable = true;
    enableBashIntegration = false;

    layouts.tabs-and-mode = ''
      layout {
        pane
        pane size=1 borderless=true {
          plugin location="status-bar"
        }
        pane size=1 borderless=true {
          plugin location="tab-bar"
        }
      }
    '';

    layouts.zoxide-picker = ''
      layout {
        pane command="${zellijNewTabZoxide}/bin/zellij-new-tab-zoxide" close_on_exit=true
        pane size=1 borderless=true {
          plugin location="compact-bar"
        }
      }
    '';

    settings = {
      # Default shell (using bash as configured in your system)
      default_shell = "bash";
      default_layout = "zoxide-picker";
      pane_frames = false;
      simplified_ui = true;

      # Mouse and interaction settings - enable for proper pane handling
      mouse_mode = true;
      copy_on_select = true;

      show_startup_tips = false;
      show_release_notes = false;

      attach_to_session = true;
      session_name = "main";
      on_force_close = "detach";
      session_serialization = true;
      serialize_pane_viewport = true;

      ui = {
        pane_frames = {
          hide_session_name = true;
        };
      };
    };

    extraConfig = ''
      keybinds {
        tab {
          bind "n" { NewTab { layout "zoxide-picker"; }; SwitchToMode "Normal"; }
          bind "N" { NewTab; SwitchToMode "Normal"; }
        }
      }
    '';
  };

  programs.eza = {
    enable = true;
    icons = "always";
    enableBashIntegration = true;
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--all"
    ];
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [
      "ignoredups"
      "erasedups"
    ];
    historySize = 50000;
    historyFileSize = 100000;
    shellOptions = [
      "histappend"
      "checkwinsize"
      "globstar"
    ];
    shellAliases = {
      "dr" = "direnv reload";
      "da" = "direnv allow";
      "nfu" = "nix flake update";
      "o" =
        "OPENCODE_PERMISSION='{\"*\":\"allow\",\"external_directory\":\"allow\",\"doom_loop\":\"allow\"}' opencode";
      "os" = "opencode";
      ".." = "z ..";
      j = "jj";
      jgf = "jj git fetch";
      jgp = "jj git push";
      jgc = "jj git clone --colocate";
      jbs = "jj bookmark set";
      jd = "jj describe";
      js = "jj show";
      jss = "jj show -s";
      jab = "jj abandon";
      jsp = "jj split";
      je = "jj edit --ignore-immutable";
      jall = "jj log -r 'all()'";
      jn = "jj new";
      jdiff = "jj diff";
      jsq = "jj squash";
      h = "hx";
      t = "trash";
      vanity = "mkp224o-amd64-64-24k -d noisebridgevanitytor noisebridge{2..7}";
    };
    initExtra = ''
      # Automatically list directory contents when changing directories
      auto_l_on_cd() {
        if [ "$__LAST_PWD" != "$PWD" ]; then
          l
          __LAST_PWD="$PWD"
        fi
      }

      export PROMPT_COMMAND="auto_l_on_cd; $PROMPT_COMMAND"
      __LAST_PWD="$PWD"
    '';
  };

  programs.kitty = {
    enable = true;
    settings = {
      hide_window_decorations = "yes";
      draw_minimal_borders = "yes";
      font_family = "CommitMono Nerd Font";
      font_size = "12";
      confirm_os_window_close = "0";
      enable_audio_bell = "no";
    };
    themeFile = "GitHub_Dark_High_Contrast";
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      remotes.origin.auto-track-bookmarks = "glob:*";
      user = {
        inherit email name;
      };

      signing = {
        behavior = "own";
        backend = "ssh";
        key = sshSigningKey;
      };

      git = {
        sign-on-push = true;
      };
      ui = {
        default-command = "log";
        editor = "hx";
        pager = "bat --style=plain";
      };
      diff.tool = [
        "difft"
        "--color=always"
        "$left"
        "$right"
      ];
    };
  };

  # Configure Zen Browser with about:config settings
  programs.zen-browser = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      DisableAppUpdate = true;
      DisableMasterPasswordCreation = true;
      DisablePasswordReveal = true;
      DisableProfileImport = true;
      ExtensionUpdate = false;
      OfferToSaveLogins = false;
      DisableFirefoxAccounts = true;
      DisableFormHistory = true;
      DisableSafeMode = true;
      DisableSetDesktopBackground = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      HardwareAcceleration = true;
      NoDefaultBookmarks = true;
      PasswordManagerEnabled = false;
      Preferences = {
        "zen.theme.border-radius" = 0;
        "zen.theme.content-element-separation" = 0;
      };
    };
    profiles.default = {
      isDefault = true;
      settings = {
        "identity.fxaccounts.enabled" = false;
      };
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        onepassword-password-manager
        sponsorblock
        darkreader
        vimium
        return-youtube-dislikes
        react-devtools
        firefox-color
        pay-by-privacy
        translate-web-pages
        user-agent-string-switcher
        copy-selected-tabs-to-clipboard
        dearrow
        violentmonkey
        tst-indent-line
      ];
      search = {
        default = "SearXNG";
        privateDefault = "SearXNG";
        force = true;
        engines = {
          "SearXNG" = {
            urls = [ { template = "https://search.extremist.software/search?q={searchTerms}"; } ];
            definedAliases = [ "@s" ];
          };
        };
      };
    };
  };

  # Override the Kitty desktop entry to always launch in fullscreen
  xdg.desktopEntries.kitty = {
    name = "Kitty";
    genericName = "Terminal Emulator";
    exec = "${pkgs.kitty}/bin/kitty --start-as=fullscreen ${zellijPersistentSession}/bin/zellij-persistent-session";
    icon = "kitty";
    type = "Application";
    categories = [
      "System"
      "TerminalEmulator"
    ];
    comment = "Fast, featureful, GPU based terminal emulator";
  };

  # Extract archives on double-click
  xdg.desktopEntries.extract-here = {
    name = "Extract Here";
    exec = "file-roller --extract-here %U";
    icon = "file-roller";
    type = "Application";
    categories = [ "Utility" ];
    mimeType = [
      "application/zip"
      "application/x-tar"
      "application/x-compressed-tar"
      "application/x-bzip-compressed-tar"
      "application/x-xz-compressed-tar"
      "application/x-zstd-compressed-tar"
      "application/gzip"
      "application/x-7z-compressed"
      "application/x-rar"
      "application/x-rar-compressed"
    ];
    noDisplay = true;
  };

  xdg.desktopEntries.betterbird = {
    name = "Betterbird";
    genericName = "Mail Client";
    exec = "${pkgs.flatpak}/bin/flatpak run eu.betterbird.Betterbird %u";
    icon = "eu.betterbird.Betterbird";
    type = "Application";
    categories = [
      "Network"
      "Email"
    ];
    mimeType = [
      "x-scheme-handler/mailto"
      "x-scheme-handler/webcal"
      "text/calendar"
    ];
    comment = "Fine-tuned Thunderbird mail client";
  };

  # Autostart applications using proper desktop files
  xdg.autostart = {
    enable = true;
    entries = [
      "${zenStartup}/share/applications/zen-startup.desktop"
      "${kittyZellijStartup}/share/applications/kitty-zellij-startup.desktop"
      "${signalStartup}/share/applications/signal-startup.desktop"
      "${betterbirdStartup}/share/applications/betterbird-startup.desktop"
      "${vesktopStartup}/share/applications/vesktop-startup.desktop"
      "${zulipStartup}/share/applications/zulip-startup.desktop"
    ];
  };

  home.file.".local/share/gnome-shell/extensions/tailscale-gnome-qs@tailscale-qs.github.io" = {
    source = "${tailscaleQsExtension}/share/gnome-shell/extensions/tailscale-gnome-qs@tailscale-qs.github.io";
    recursive = true;
  };

  systemd.user.services.nasa-apod-wallpaper = {
    Unit = {
      Description = "Fetch NASA APOD wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${nasaApodWallpaper}/bin/nasa-apod-wallpaper";
    };
  };

  systemd.user.timers.nasa-apod-wallpaper = {
    Unit.Description = "Refresh NASA APOD wallpaper daily";
    Timer = {
      OnStartupSec = "0";
      OnUnitActiveSec = "1d";
      Unit = "nasa-apod-wallpaper.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Set Zen Browser as default
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
      "x-scheme-handler/mailto" = "betterbird.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-bzip-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-zstd-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/gzip" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/x-rar" = "org.gnome.FileRoller.desktop";
      "application/x-rar-compressed" = "org.gnome.FileRoller.desktop";
    };
  };

  home.file.".config/opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    mcp = {
      linear = {
        type = "remote";
        url = "https://mcp.linear.app/mcp";
        enabled = true;
      };
    };
  };

  home.file.".config/opencode/tui.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/tui.json";
    keybinds = {
      leader = "ctrl+x";
      command_list = "<leader>p";
      variant_cycle = "<leader>t";
    };
  };

  xdg.userDirs = {
    enable = true;
    setSessionVariables = true;
  };

  gtk = {
    enable = true;
    gtk4.theme = config.gtk.theme;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

}
