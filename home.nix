{ config, pkgs, inputs, ... }:

{
  home.username = "jet";
  home.stateVersion = "23.05";

  home.packages = with pkgs; [
    code-cursor
    ghidra-bin
    kitty
    zellij
    jujutsu
    vlc
    docker
    btop
    inputs.zen-browser.packages."${pkgs.system}".twilight-official
    nerd-fonts.commit-mono
    prismlauncher
    steam
    qbittorrent-enhanced
    openexr # for omelia
    gimp3
    obs-studio
    inkscape
    blender
    kdePackages.kdenlive
    android-studio
    bat
    zoxide
    eza
    ripgrep
    unzip
    jq
    direnv
    mullvad-vpn
  ];

  programs.zellij = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      # Default shell (using bash as configured in your system)
      default_shell = "bash";
      default_layout = "compact";
      copy_on_select = false;
      
      # Mouse and interaction settings
      mouse_mode = true;
      
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
      jd = "jj describe";
      js = "jj show";
      je = "jj edit --ignore-immutable";
      jn = "jj new";
      jdiff = "jj diff";
      ns = "sudo nixos-rebuild switch --flake ~/Documents/nixos-config#jet";
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
        editor = "hx";
        pager = "bat";
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
    ];
  };
}