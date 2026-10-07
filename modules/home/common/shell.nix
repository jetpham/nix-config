{ homeLib, pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      format = "$directory$nix_shell$cmd_duration$line_break$character";
      directory.truncation_length = 3;
      nix_shell.format = "[$symbol]($style) ";
      cmd_duration.min_time = 500;
      character.success_symbol = "[❯](bold green)";
      character.error_symbol = "[❯](bold red)";
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
      ".." = "z ..";
    };
    initExtra = ''
      # Automatically list directory contents when changing directories
      auto_l_on_cd() {
        if [ "''${__LAST_PWD:-}" != "$PWD" ]; then
          l
          __LAST_PWD="$PWD"
          ${homeLib.zellijSyncTabName}/bin/zellij-sync-tab-name || true
        fi
      }

      __LAST_PWD="$PWD"

      case ";''${PROMPT_COMMAND:-};" in
        *";auto_l_on_cd;"*) ;;
        *) PROMPT_COMMAND="auto_l_on_cd''${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
      esac
      export PROMPT_COMMAND
    '';
  };
}
