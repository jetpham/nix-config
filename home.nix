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
    "org/nemo/preferences" = {
      show-hidden-files = true;
      default-folder-viewer = "list-view";
      show-location-entry = true;
      show-full-path-titles = true;
      date-format = "informal";
    };
    "org/nemo/window-state" = {
      side-pane-view = "treeview";
    };
    "org/nemo/list-view" = {
      default-zoom-level = "small";
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

    # CLI
    bat
    ffmpeg-full
    claude-code
    opencode
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
    inkscape
    kdePackages.kdenlive
    logseq
    nemo-with-extensions
    obs-studio
    prismlauncher
    qbittorrent-enhanced
    signal-desktop
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
    enableBashIntegration = true;

    settings = {
      # Default shell (using bash as configured in your system)
      default_shell = "bash";
      default_layout = "compact";
      pane_frames = false;

      # Mouse and interaction settings - enable for proper pane handling
      mouse_mode = true;
      copy_on_select = true;

      show_startup_tips = false;
      show_release_notes = false;

      on_force_close = "detach";
    };
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
      "ow" =
        "URL=\"https://$(tailscale status --json | jq -r '.Self.DNSName | sub(\"\\.$\"; \"\")')\"; printf 'Open on phone: %s\\n' \"$URL\"; tailscale serve --bg 443 http://127.0.0.1:4096; opencode web --hostname 127.0.0.1 --port 4096";
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
      dj = "ffmpeg -f pulse -i alsa_output.pci-0000_c1_00.6.analog-stereo.monitor -ac 2 -ar 44100 -acodec libmp3lame -b:a 128k -content_type audio/mpeg -f mp3 'icecast://nbradio:nbradio@beyla:8005/live'";
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
      "inode/directory" = "nemo.desktop";
      "application/zip" = "extract-here.desktop";
      "application/x-tar" = "extract-here.desktop";
      "application/x-compressed-tar" = "extract-here.desktop";
      "application/x-bzip-compressed-tar" = "extract-here.desktop";
      "application/x-xz-compressed-tar" = "extract-here.desktop";
      "application/x-zstd-compressed-tar" = "extract-here.desktop";
      "application/gzip" = "extract-here.desktop";
      "application/x-7z-compressed" = "extract-here.desktop";
      "application/x-rar" = "extract-here.desktop";
      "application/x-rar-compressed" = "extract-here.desktop";
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

  xdg.userDirs.enable = true;

  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

}
