{
  homeLib,
  pkgs,
  ...
}:

let
  chromeDevtoolsMcpShell = pkgs.runCommand "chrome-devtools-mcp-shell-path" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.bash}/bin/bash "$out/bin/sh"
  '';
in

{
  home.file.".agents/skills/check-pr".source = "${homeLib.greptileSkills}/check-pr";
  home.file.".agents/skills/greploop".source = "${homeLib.greptileSkills}/greploop";
  home.file.".agents/skills/fuzz/SKILL.md".text = builtins.readFile ../skills/fuzz.md;
  home.file.".agents/skills/ecmascript-modernization".source =
    "${homeLib.inthAgentSkills}/ecmascript-modernization";

  home.file.".config/opencode/commands/ecmascript-modernization.md".text = ''
    ---
    description: Modernize JavaScript or TypeScript to ECMAScript APIs
    agent: build
    ---

    First load the `ecmascript-modernization` skill with the skill tool.

    Use it for this JavaScript or TypeScript ECMAScript modernization request:

    $ARGUMENTS

    Treat the arguments as an ECMAScript edition, file pattern, or task scope. If no arguments are provided, inspect the project for safe modernization opportunities. Before editing, check the runtime baseline, TypeScript version, and `tsconfig.json`.
  '';

  home.file.".config/opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    plugin = [ "opencode-with-claude" ];
    permission = "allow";
    server = {
      hostname = "127.0.0.1";
      port = 4096;
    };
    mcp.chrome-devtools = {
      type = "local";
      command = [
        "${pkgs.nodejs_24}/bin/npx"
        "-y"
        "chrome-devtools-mcp@1.3.0"
        "--executable-path=${pkgs.google-chrome}/bin/google-chrome-stable"
        "--no-usage-statistics"
        "--no-performance-crux"
      ];
      enabled = true;
      timeout = 30000;
      environment = {
        CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1";
        NO_UPDATE_NOTIFIER = "1";
        NPM_CONFIG_AUDIT = "false";
        NPM_CONFIG_FUND = "false";
        NPM_CONFIG_UPDATE_NOTIFIER = "false";
        PATH = pkgs.lib.makeBinPath [
          pkgs.nodejs_24
          chromeDevtoolsMcpShell
          pkgs.coreutils
        ];
      };
    };
    model = "openai/gpt-5.6-sol-fast";
    small_model = "openai/gpt-5.4-mini-fast";
    provider.openai.models."gpt-5.6-sol-fast".options = {
      reasoningEffort = "low";
    };
    share = "disabled";
  };

  home.file.".config/opencode/AGENTS.md".text = ''
    # NixOS Rules

    - This machine is NixOS. Prefer the Nix way for installing and running tools.
    - Do not suggest `apt`, `dnf`, `pacman`, `brew`, `npm -g`, `pip install`, `cargo install`, `curl | sh`, or manual installers unless explicitly asked.
    - If a repo has `flake.nix`, treat it as the source of truth for project tooling.
    - If a needed tool belongs to the project, add it to `flake.nix` or the dev shell instead of installing it another way.
    - If a repo has `flake.nix`, ensure `.envrc` contains `use flake` unless the repo intentionally uses a different setup.
    - If there is no `flake.nix` and the tool is only needed temporarily, prefer `nix shell nixpkgs#<pkg> -c <command>`.
    - For persistent tools, prefer declarative Nix configuration.
    - Prefer `direnv` or `nix develop` before deciding a tool is missing.
    - Do not put temporary code work, clones, generated project files, or Git worktrees under `/tmp`; use `~/Documents/tmp` instead so work is less likely to be cleared.
    - Never run `nixos-rebuild`, `nh os switch`, `nhs`, or other system switch commands unless explicitly asked.
  '';

  home.file.".config/opencode/tui.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/tui.json";
    keybinds = {
      leader = "ctrl+x";
      command_list = "<leader>p";
      variant_cycle = "<leader>t";
    };
  };
}
