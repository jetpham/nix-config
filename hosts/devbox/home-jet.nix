{ pkgs, ... }:

{
  imports = [ ./home-zellij.nix ];

  home.username = "jet";
  home.homeDirectory = "/home/jet";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    bat
    btop
    difftastic
    fd
    gh
    git
    helix
    jq
    jujutsu
    nil
    nixfmt
    opencode
    ripgrep
    zoxide
  ];

  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      umask 0002

      opencode() {
        dir="''${OPENCODE_DEVBOX_DIR:-$PWD}"
        case "$dir" in
          /srv/dev|/srv/dev/*) ;;
          *) dir=/srv/dev ;;
        esac

        command opencode attach http://127.0.0.1:4096 --dir "$dir" "$@"
      }
    '';
    shellAliases = {
      h = "hx";
      j = "jj";
      o = "opencode";
    };
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    git = true;
    icons = "always";
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };
}
