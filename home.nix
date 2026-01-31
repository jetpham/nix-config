{ config, pkgs, inputs, lib, ... }:

{
  imports = [ inputs.zen-browser.homeModules.default ];

  home.username = "jet";
  home.stateVersion = "23.05";

  # Configure GNOME settings
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      clock-format = "12h";
      clock-show-weekday = true;
      enable-animations = false;
      enable-hot-corners = false;
    };
    "org/gnome/system/location" = {
      enabled = true;
    };
    "org/gnome/desktop/background" = {
      picture-uri =
        "file:///home/jet/Documents/nix-config/cat.png";
      picture-uri-dark =
        "file:///home/jet/Documents/nix-config/cat.png";
      picture-options = "wallpaper";
    };
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
    };
    "org/gtk/settings/file-chooser" = {
      clock-format = "12h";
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      disable-while-typing = true;
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
    git
    wget
    helix
    kitty
    zellij
    jujutsu
    vlc
    docker
    nerd-fonts.commit-mono
    qbittorrent-enhanced
    gimp3
    inkscape
    bat
    zoxide
    eza
    ripgrep
    unzip
    direnv
    gnomeExtensions.hide-top-bar
    gnomeExtensions.wifi-qrcode
    gnomeExtensions.system-monitor-next
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.emoji-copy
    signal-desktop
    tree
    google-chrome
    mullvad-vpn
    font-manager
    steam
    appimage-run
    gh
    beeper
    antigravity-fhs
    mkp224o
    claude-code
    logseq
    element-desktop
    zulip
  ];


  # Set environment variables for OpenCL
  home.sessionVariables = {
    OCL_ICD_VENDORS = "/etc/OpenCL/vendors";
    POCL_DEVICES = "cpu";
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
      };
    };
    languages = {
      haskell = {
        config = {
          end-of-line-diagnostics = "hint";
        };
        "inline-diagnostics" = {
          cursor-line = "hint";
          other-lines = "hint";
        };
      };
      rust = {
        config = {
          end-of-line-diagnostics = "hint";
        };
        "inline-diagnostics" = {
          cursor-line = "hint";
          other-lines = "hint";
        };
      };
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

  programs.mullvad-vpn.enable = true;

  programs.eza = {
    enable = true;
    icons = "always";
    enableBashIntegration = true;
    git = true;
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
    shellAliases = {
      ll = "eza -l";
      la = "eza -la";
      ".." = "cd ..";
      c = "cd && ls";
      j = "jj";
      jgf = "jj git fetch";
      jgp = "jj git push";
      jgc = "jj git clone --colocate";
      jbs = "jj bookmark set";
      jd = "jj describe";
      js = "jj show";
      je = "jj edit --ignore-immutable";
      jall = "jj log -r 'all()'";
      jn = "jj new";
      jdiff = "jj diff";
      jsq = "jj squash";
      nhs = "nh os switch .";
      nd = "nix develop";
      h = "hx";
      vanity = "mkp224o-amd64-64-24k -d noisebridgevanitytor noisebridge{2..7}";
    };
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
      "ctrl+c" = "copy_and_clear_or_interrupt";
      "ctrl+shift+v" = "paste_from_clipboard";
      "ctrl+v" = "paste_from_clipboard";
    };
    themeFile = "GitHub_Dark_High_Contrast";
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      remotes.origin.auto-track-bookmarks = "glob:*";
      user = {
        email = "jetthomaspham@gmail.com";
        name = "Jet Pham";
      };

      signing = {
        behavior = "own";
        backend = "ssh";
        key = "~/.ssh/id_ed25519.pub";
      };

      git = {
        sign-on-push = true;
      };
      ui = {
        default-command = "log";
        editor = "hx";
        pager = "bat --style=plain";
      };
    };
  };

  # Configure Zen Browser with about:config settings
  programs.zen-browser = {
    enable = true;
    policies = {
      Preferences = {
        "zen.theme.border-radius" = 0;
        "zen.theme.content-element-separation" = 0;
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
    categories = ["System" "TerminalEmulator"];
    comment = "Fast, featureful, GPU based terminal emulator";
  };

  # Autostart applications using proper desktop files
  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs.kitty}/share/applications/kitty.desktop"
      "${config.programs.zen-browser.package}/share/applications/zen.desktop"

      "${pkgs.beeper}/share/applications/beepertexts.desktop"
    ];
  };

  # Enable rootless Podman with Home Manager
  services.podman = {
    enable = true;
    autoUpdate.enable = true;
  };
}
