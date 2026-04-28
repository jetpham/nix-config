{ pkgs, homeLib, ... }:

{
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
        pane command="${homeLib.zellijNewTabZoxide}/bin/zellij-new-tab-zoxide" close_on_exit=true
        pane size=1 borderless=true {
          plugin location="compact-bar"
        }
      }
    '';

    settings = {
      default_shell = "bash";
      default_layout = "zoxide-picker";
      pane_frames = false;
      simplified_ui = true;
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

  programs.ghostty = {
    enable = true;
    settings = {
      window-decoration = false;
      font-family = "CommitMono Nerd Font";
      font-size = 12;
      confirm-close-surface = false;
      bell-features = "no-audio";
      theme = "GitHub Dark High Contrast";
      fullscreen = true;
    };
  };

  xdg.desktopEntries.ghostty = {
    name = "Ghostty";
    genericName = "Terminal Emulator";
    exec = "${pkgs.ghostty}/bin/ghostty --fullscreen=true -e ${homeLib.zellijPersistentSession}/bin/zellij-persistent-session";
    icon = "com.mitchellh.ghostty";
    type = "Application";
    categories = [
      "System"
      "TerminalEmulator"
    ];
    comment = "Fast, native terminal emulator";
  };
}
