{ pkgs, ... }:

{
  programs.zellij = {
    enable = true;
    enableBashIntegration = false;

    layouts.zoxide-picker = ''
      layout {
        pane command="${pkgs.bashInteractive}/bin/bash" close_on_exit=true
        pane size=1 borderless=true {
          plugin location="compact-bar"
        }
      }
    '';

    settings = {
      default_shell = "${pkgs.bashInteractive}/bin/bash";
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
    };
  };
}
