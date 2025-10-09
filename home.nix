{ config, pkgs, inputs, lib, ... }:

{
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
        "file:///home/jet/Documents/nixos-config/cat.png";
      picture-uri-dark =
        "file:///home/jet/Documents/nixos-config/cat.png";
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
      ];
    };
  };

  home.packages = with pkgs; [
    git
    wget
    helix
    code-cursor-fhs
    kitty
    zellij
    jujutsu
    vlc
    docker
    inputs.zen-browser.packages."${pkgs.system}".twilight-official
    nerd-fonts.commit-mono
    prismlauncher
    qbittorrent-enhanced
    gimp3
    obs-studio
    inkscape
    blender
    kdePackages.kdenlive
    bat
    zoxide
    eza
    ripgrep
    unzip
    direnv
    gnomeExtensions.hide-top-bar
    signal-desktop
    tree
    figma-agent
    figma-linux
    google-chrome
    tor-browser
    mullvad-vpn
    element-desktop
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
      ns = "sudo nixos-rebuild switch --flake ~/Documents/nixos-config#jet";
      nd = "nix develop";
      h = "hx";
      
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
        push-new-bookmarks = true;
      };
      ui = {
        default-command = "log";
        editor = "hx";
        pager = "bat --style=plain";
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
      "${inputs.zen-browser.packages."${pkgs.system}".twilight-official}/share/applications/zen-twilight.desktop"
      "${pkgs.code-cursor}/share/applications/cursor.desktop"
      "${pkgs.signal-desktop}/share/applications/signal.desktop"
    ];
  };

  # Enable rootless Podman with Home Manager
  services.podman = {
    enable = true;
    autoUpdate.enable = true;
  };
}
