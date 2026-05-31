{ pkgs, ... }:

{
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
      format = "$directory\${custom.jj}$nix_shell$cmd_duration$line_break$character";
      directory.truncation_length = 3;
      git_branch.disabled = true;
      git_status.disabled = true;
      nix_shell.format = "[$symbol]($style) ";
      cmd_duration.min_time = 500;
      character.success_symbol = "[❯](bold green)";
      character.error_symbol = "[❯](bold red)";
      custom.jj = {
        when = "jj-starship detect";
        shell = [ "${pkgs.jj-starship}/bin/jj-starship" ];
        format = "$output ";
      };
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
}
