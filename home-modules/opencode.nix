{ homeLib, ... }:

{
  home.file.".agents/skills/check-pr".source = "${homeLib.greptileSkills}/check-pr";
  home.file.".agents/skills/greploop".source = "${homeLib.greptileSkills}/greploop";
  home.file.".agents/skills/fuzz/SKILL.md".text = builtins.readFile ./skills/fuzz.md;

  home.file.".config/opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    plugin = [ "opencode-with-claude" ];
    permission = {
      "*" = "allow";
      external_directory = "allow";
      doom_loop = "allow";
    };
    mcp.linear = {
      type = "remote";
      url = "https://mcp.linear.app/mcp";
      enabled = true;
    };
    model = "openai/gpt-5.5-fast";
    small_model = "openai/gpt-5.4-mini-fast";
    provider.openai.models."gpt-5.5-fast".options = {
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
