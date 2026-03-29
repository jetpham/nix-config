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
  t3 = pkgs.writeShellApplication {
    name = "t3";
    runtimeInputs = [ pkgs.nodejs_24 ];
    text = ''
      exec npx --yes --package=t3@0.0.14 t3 "$@"
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
        exec ${pkgs.bashInteractive}/bin/bash -i
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
        fi
        exit 0
      fi

      tab_name="$(${pkgs.coreutils}/bin/basename "$dir")"
      if [ "$dir" = "/" ]; then
        tab_name="/"
      fi

      cd "$dir"

      if [ -n "''${ZELLIJ:-}" ]; then
        ${pkgs.zellij}/bin/zellij action rename-tab "$tab_name" >/dev/null 2>&1 || true
      fi

      exec ${pkgs.bashInteractive}/bin/bash -i
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
  browserAudio = pkgs.writeShellApplication {
    name = "browser-audio";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.ffmpeg-full
      pkgs.fzf
      pkgs.gawk
      pkgs.gnugrep
      pkgs.jq
      pkgs.pulseaudio
      pkgs.qpwgraph
      pkgs.pavucontrol
      pkgs.procps
    ];
    text = ''
            set -euo pipefail

            sink_name="''${BROWSER_AUDIO_SINK:-browser-radio}"
            sink_description="''${BROWSER_AUDIO_DESCRIPTION:-Browser Radio}"
            bitrate="''${BROWSER_AUDIO_BITRATE:-128k}"

      usage() {
        printf '%s\n' \
          "Usage: browser-audio <command> [args]" \
          "" \
          "Commands:" \
          "  setup              Create the dedicated browser sink if needed" \
          "  pick               Pick a live playback stream and move it to the sink" \
          "  route <regex>      Move matching playback streams to the sink" \
          "  status             Show the sink and any streams already routed to it" \
          "  open               Open pavucontrol and qpwgraph for manual routing" \
          "  cast <icecast-url> Stream the sink monitor to Icecast/Shoutcast with ffmpeg" \
          "  cast-pick <url>    Pick a live stream, route it, then start casting" \
          "  stop               Stop prior ffmpeg jobs and remove the sink" \
          "  remove             Remove the dedicated sink" \
          "" \
          "Notes:" \
          "  - If your browser exposes a tab as its own playback stream, pick can isolate it." \
          "  - Otherwise, launch a dedicated browser instance for music and route that stream."
      }

            ensure_sink() {
              if ! pactl list short sinks | awk '{print $2}' | grep -Fxq "$sink_name"; then
                pactl load-module module-null-sink \
                  sink_name="$sink_name" \
                  sink_properties="device.description=$sink_description" >/dev/null
              fi
            }

      sink_module_id() {
        pactl -f json list modules | jq -r --arg sink_name "$sink_name" '
          .[]
                | select(.name == "module-null-sink")
                | select((.argument // "") | contains("sink_name=" + $sink_name))
                | .index
        ' | head -n1
      }

      stop_existing_casts() {
        pkill -f "ffmpeg.*$sink_name\.monitor" >/dev/null 2>&1 || true
      }

      remove_sink() {
        local module_id

        module_id="$(sink_module_id || true)"
        if [ -n "$module_id" ] && [ "$module_id" != "null" ]; then
          pactl unload-module "$module_id"
        fi
      }

      reset_state() {
        stop_existing_casts
        remove_sink
      }

            stream_rows() {
              pactl -f json list sink-inputs | jq -r '
                .[]
                | [
                    (.index | tostring),
                    (.sink | tostring),
                    (.properties."application.name" // "unknown-app"),
                    (.properties."media.name" // .properties."node.description" // "unknown-media"),
                    (.properties."application.process.binary" // "unknown-bin")
                  ]
                | @tsv
              '
            }

            pick_stream() {
              local selection

              selection="$(stream_rows | fzf \
                --delimiter=$'\t' \
                --with-nth=3,4,5 \
                --layout=reverse \
                --border \
                --prompt='audio> ' \
                --header=$'Pick a live playback stream to route into browser-radio\napp | media | binary' \
                --exit-0)"

              if [ -z "$selection" ]; then
                exit 0
              fi

              pactl move-sink-input "$(printf '%s\n' "$selection" | cut -f1)" "$sink_name"
            }

            route_matching() {
              local pattern="$1"
              local matches

              matches="$(stream_rows | grep -Ei "$pattern" || true)"
              if [ -z "$matches" ]; then
                printf 'No playback streams matched %s\n' "$pattern" >&2
                exit 1
              fi

        printf '%s\n' "$matches" | while IFS=$'\t' read -r stream_id _rest; do
          [ -n "$stream_id" ] || continue
          pactl move-sink-input "$stream_id" "$sink_name"
        done
      }

            show_status() {
              printf 'Sink: %s\n' "$sink_name"
              pactl list short sinks | awk -v sink="$sink_name" '$2 == sink {print}'
              printf '\nStreams on %s:\n' "$sink_name"
              pactl -f json list sink-inputs | jq -r --arg sink_name "$sink_name" --argjson sink_index "$(pactl list short sinks | awk -v sink="$sink_name" '$2 == sink {print $1; exit}')" '
                .[]
                | select(.sink == $sink_index)
                | "- #\(.index) \(.properties["application.name"] // "unknown-app") :: \(.properties["media.name"] // .properties["node.description"] // "unknown-media")"
              '
            }

            cast_sink() {
              local url="$1"
              local rest auth host_path endpoint
              local tmpdir fifo ffmpeg_pid curl_pid ffmpeg_status curl_status interrupted=0

              case "$url" in
                icecast://*)
                  rest="''${url#icecast://}"
                  auth="''${rest%%@*}"
                  host_path="''${rest#*@}"
                  endpoint="http://''${host_path}"
                  ;;
                *)
                  printf 'cast requires an icecast:// URL\n' >&2
                  exit 1
                  ;;
              esac

              tmpdir="$(mktemp -d)"
              fifo="$tmpdir/audio.mp3"
              mkfifo "$fifo"

              cleanup_cast() {
                local pid
                local waited

                trap - INT TERM EXIT

                for pid in "''${ffmpeg_pid:-}" "''${curl_pid:-}"; do
                  [ -n "$pid" ] || continue
                  kill "$pid" >/dev/null 2>&1 || true
                done

                for pid in "''${ffmpeg_pid:-}" "''${curl_pid:-}"; do
                  [ -n "$pid" ] || continue
                  waited=0
                  while kill -0 "$pid" >/dev/null 2>&1; do
                    if [ "$waited" -ge 20 ]; then
                      kill -9 "$pid" >/dev/null 2>&1 || true
                      break
                    fi
                    sleep 0.1
                    waited=$((waited + 1))
                  done
                  wait "$pid" >/dev/null 2>&1 || true
                done

                rm -rf "$tmpdir"
                if [ "$interrupted" -eq 1 ]; then
                  exit 130
                fi
              }

              trap 'interrupted=1; cleanup_cast' INT TERM
              trap cleanup_cast EXIT

              curl \
                --silent \
                --show-error \
                --http1.0 \
                --user "$auth" \
                --header 'Content-Type: audio/mpeg' \
                --request SOURCE \
                --data-binary @- \
                "$endpoint" <"$fifo" &
              curl_pid=$!

              ffmpeg \
                -y \
                -hide_banner \
                -loglevel warning \
                -f pulse \
                -channel_layout stereo \
                -i "$sink_name.monitor" \
                -ac 2 \
                -ar 44100 \
                -acodec libmp3lame \
                -b:a "$bitrate" \
                -id3v2_version 0 \
                -write_xing 0 \
                -f mp3 \
                "$fifo" &
              ffmpeg_pid=$!

              set +e
              wait "$ffmpeg_pid"
              ffmpeg_status=$?
              wait "$curl_pid"
              curl_status=$?
              set -e

              trap - INT TERM EXIT
              rm -rf "$tmpdir"

              if [ "$ffmpeg_status" -ne 0 ]; then
                return "$ffmpeg_status"
              fi

              if [ "$curl_status" -ne 0 ]; then
                return "$curl_status"
              fi
            }

            command="''${1:-help}"
            case "$command" in
              setup)
                ensure_sink
                show_status
                ;;
              pick)
                ensure_sink
                pick_stream
                show_status
                ;;
              route)
                ensure_sink
                if [ "''${2:-}" = "" ]; then
                  printf 'route requires a regex\n' >&2
                  exit 1
                fi
                route_matching "$2"
                show_status
                ;;
              status)
                ensure_sink
                show_status
                ;;
              open)
                ensure_sink
                pavucontrol >/dev/null 2>&1 &
                qpwgraph >/dev/null 2>&1 &
                ;;
            cast)
              reset_state
              ensure_sink
              if [ "''${2:-}" = "" ]; then
                printf 'cast requires an icecast:// URL\n' >&2
                exit 1
                fi
              cast_sink "$2"
              ;;
            cast-pick)
              reset_state
              ensure_sink
              if [ "''${2:-}" = "" ]; then
                printf 'cast-pick requires an icecast:// URL\n' >&2
                exit 1
              fi
              pick_stream
              show_status
              cast_sink "$2"
              ;;
            stop)
              reset_state
              ;;
            remove)
              remove_sink
              ;;
              help|-h|--help)
                usage
                ;;
              *)
                printf 'Unknown command: %s\n\n' "$command" >&2
                usage >&2
                exit 1
                ;;
            esac
    '';
  };
  zenRadio = pkgs.writeShellApplication {
    name = "zen-radio";
    runtimeInputs = [
      config.programs.zen-browser.package
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      profile_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/zen-radio-profile"
      mkdir -p "$profile_dir"

      exec zen --new-instance --profile "$profile_dir" "$@"
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
      DNS="$(tailscale status --json | jq -r '.Self.DNSName')"
      DNS="''${DNS%.}"
      sudo -v
      sudo tailscale serve --bg 4096
      exec opencode web --hostname 127.0.0.1 --port 4096
    '')

    # CLI
    bat
    browserAudio
    ffmpeg-full
    claude-code
    opencode
    t3
    zellijNewTabZoxide
    zellijSyncTabName
    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
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
    zenRadio
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
      default_layout = "tabs-and-mode";
      pane_frames = false;
      simplified_ui = true;

      # Mouse and interaction settings - enable for proper pane handling
      mouse_mode = true;
      copy_on_select = true;

      show_startup_tips = false;
      show_release_notes = false;

      on_force_close = "detach";

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
      "c" = "claude";
      "o" = "opencode";
      "ou" = "OPENCODE_PERMISSION='\"allow\"' opencode";
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
    keybindings = {
      "ctrl+shift+c" = "copy_and_clear_or_interrupt";
      "ctrl+shift+v" = "paste_from_clipboard";
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
    exec = "kitty --start-as=fullscreen";
    icon = "kitty";
    type = "Application";
    categories = [
      "System"
      "TerminalEmulator"
    ];
    comment = "Fast, featureful, GPU based terminal emulator";
  };

  xdg.desktopEntries.zen-radio = {
    name = "Zen Radio";
    genericName = "Dedicated Browser Audio";
    exec = "zen-radio %U";
    icon = "zen";
    type = "Application";
    categories = [
      "Network"
      "WebBrowser"
      "AudioVideo"
    ];
    comment = "Dedicated Zen instance for isolating music playback";
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

  # Autostart applications using proper desktop files
  xdg.autostart = {
    enable = true;
    entries = [
      pkgs.kitty
      config.programs.zen-browser.package
    ];
  };

  # Set Zen Browser as default
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "zen.desktop";
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "x-scheme-handler/about" = "zen.desktop";
      "x-scheme-handler/unknown" = "zen.desktop";
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

  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        # Use maildir instead of mbox — faster for large mailboxes
        "mail.serverDefaultStoreContractID" = "@mozilla.org/msgstore/maildirstore;1";

        # Increase IMAP connection limits
        "mail.server.default.max_cached_connections" = 10;
        "mail.imap.max_cached_connections" = 10;

        # IMAP IDLE — server pushes new mail instantly (no polling delay)
        "mail.server.default.use_idle" = true;

        # Poll every 1 minute as fallback when IDLE drops
        "mail.server.default.check_new_mail" = true;
        "mail.server.default.check_time" = 1;

        # Faster IMAP sync
        "mail.imap.min_time_between_cleanups" = 300;
        "mail.imap.fetch_by_chunks" = true;
        "mail.imap.chunk_size" = 65536;
        "mail.imap.chunk_add" = 16384;

        # Reduce timeouts (fail fast instead of hanging)
        "mail.server.default.timeout" = 60;
        "mailnews.tcptimeout" = 60;

        # Network performance
        "network.http.max-connections" = 48;
        "network.http.max-persistent-connections-per-server" = 10;
        "network.dns.disablePrefetch" = false;

        # Cache messages offline for instant reading
        "mail.server.default.offline_download" = true;
        "mail.server.default.download_on_biff" = true;

        # Auto-compact folders when >20MB wasted (keeps mbox files lean)
        "mail.purge_threshhold_mb" = 20;
        "mail.prompt_purge_threshhold" = false;

        # Block remote content by default (tracking pixels, slow image loads)
        "mailnews.message_display.disable_remote_image" = true;

        # Disable adaptive junk filter (server-side spam is better)
        "mail.spam.manualMark" = true;
        "mailnews.ui.junk.firstuse" = false;
        "mailnews.ui.junk.manualMarkAsJunkMarksRead" = true;

        # Prefetch next message while reading current one
        "mail.server.default.autosync_offline_stores" = true;

        # Open links in default browser (Zen) instead of Thunderbird's internal browser
        "network.protocol-handler.warn-external.http" = false;
        "network.protocol-handler.warn-external.https" = false;
        "network.protocol-handler.expose-all" = true;

        # Simplify message rendering
        "mailnews.display.prefer_plaintext" = false;
        "mailnews.display.disallow_mime_handlers" = 0;
        "mailnews.display.html_as" = 0;

        # Disable return receipt prompts
        "mail.incorporate.return_receipt" = 0;
        "mail.receipt.request_return_receipt_on" = false;

        # Disable chat and calendar background connections
        "mail.chat.enabled" = false;
        "calendar.integration.notify" = false;

        # Disable unnecessary features
        "mail.phishing.detection.enabled" = false;
        "mail.rights.version" = 1;
        "mail.shell.checkDefaultClient" = false;
        "mail.spotlight.enable" = false;

        # Faster UI rendering
        "gfx.webrender.all" = true;

        # Network keepalive
        "network.http.keep-alive.timeout" = 600;
        "network.http.response.timeout" = 120;

        # Fix UI not updating after delete/archive — move to next message automatically
        "mail.delete_matches_sort_order" = true;
        "mail.advance_on_delete" = true;
      };
    };
  };

  home.file.".claude/settings.json".text = builtins.toJSON {
    allowedTools = [
      "Read"
      "Glob"
      "Grep"
      "Write"
      "Edit"
      "Agent"
      "WebFetch"
      "WebSearch"
    ];
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
