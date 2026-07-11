{ pkgs, ... }:

let
  chromeDevtoolsMcpShell = pkgs.runCommand "chrome-devtools-mcp-shell-path" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.bash}/bin/bash "$out/bin/sh"
  '';
in

{
  home.username = "agent";
  home.homeDirectory = "/home/agent";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    bat
    btop
    difftastic
    fd
    gh
    git
    google-chrome
    helix
    jq
    jujutsu
    nil
    nixfmt
    nodejs_24
    opencode
    ripgrep
  ];

  home.file.".config/opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
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
        "--headless"
        "--isolated"
        "--executable-path=${pkgs.google-chrome}/bin/google-chrome-stable"
        "--viewport=1440x900"
        "--no-usage-statistics"
        "--no-performance-crux"
      ];
      enabled = true;
      timeout = 30000;
      environment = {
        CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1";
        CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS = "1";
        CI = "1";
        NO_UPDATE_NOTIFIER = "1";
        NPM_CONFIG_AUDIT = "false";
        NPM_CONFIG_CACHE = "/var/lib/opencode-agent/cache/npm";
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
    provider.openai.models."gpt-5.6-sol-fast".options.reasoningEffort = "low";
    share = "disabled";
  };

  home.file.".config/opencode/AGENTS.md".text = ''
    # Devbox Context

    - This machine is `devbox`, a dedicated NixOS development and agent box accessed through Tailscale.
    - The user normally works from a local laptop and attaches to this opencode server with `od`.
    - The opencode server process runs as user `agent` and should treat `/srv/dev` as the primary workspace.
    - Avoid using `/home/jet` for project work. That home belongs to the interactive human user and may not be accessible to the `agent` service.
    - Put clones, worktrees, temporary project files, generated repos, and scratch development work under `/srv/dev`.
    - Prefer one project directory per repo under `/srv/dev`, for example `/srv/dev/my-app`.

    # Remote Web Development

    - Web apps run on devbox but are viewed from the user's local browser through Tailscale.
    - Bind dev servers to `0.0.0.0` or the devbox Tailscale IP, not only `127.0.0.1`, when the user needs local browser access.
    - Tell the user to open URLs as `http://devbox:<port>`.
    - Tailnet-only dev ports are open for common ranges: `3000-3999`, `5000-5999`, `6006`, `8000-8999`, and `8080`.
    - Examples: `npm run dev -- --host 0.0.0.0 --port 5173`, `next dev -H 0.0.0.0 -p 3000`, `python manage.py runserver 0.0.0.0:8000`.
    - Do not expose development servers on the public internet unless the user explicitly asks.

    # Browser Debugging

    - Chrome DevTools MCP is available and runs headless on devbox.
    - Use Chrome DevTools MCP for inspecting local dev apps, console logs, network requests, screenshots, accessibility snapshots, and performance traces.
    - Prefer testing devbox-hosted apps through `http://127.0.0.1:<port>` from the agent when possible, and tell the user the matching local URL `http://devbox:<port>`.

    # NixOS Rules

    - This machine is NixOS. Prefer the Nix way for installing and running tools.
    - Do not suggest `apt`, `dnf`, `pacman`, `brew`, `npm -g`, `pip install`, `cargo install`, `curl | sh`, or manual installers unless explicitly asked.
    - If a repo has `flake.nix`, treat it as the source of truth for project tooling.
    - If a needed tool belongs to the project, add it to `flake.nix` or the dev shell instead of installing it another way.
    - If a repo has `flake.nix`, ensure `.envrc` contains `use flake` unless the repo intentionally uses a different setup.
    - If there is no `flake.nix` and the tool is only needed temporarily, prefer `nix shell nixpkgs#<pkg> -c <command>`.
    - For persistent tools, prefer declarative Nix configuration.
    - Prefer `direnv` or `nix develop` before deciding a tool is missing.
    - Do not put temporary code work, clones, generated project files, or Git worktrees under `/tmp`; use `/srv/dev` instead.
    - Never run `nixos-rebuild`, `nh os switch`, `nhs`, or other system switch commands unless explicitly asked.

    # GitCafe CLI (cafe)

    - gitcafe (gitcafe.dev) is the git forge we use for developing our
      projects — gitcafe itself, kiln, libgitz, and more. Repos live at
      `git@gitcafe.dev:owner/name.git`; the web UI is `https://app.gitcafe.dev`.
    - `cafe` is on PATH and authenticates automatically against
      `https://api.gitcafe.dev` (it reads the API token from
      `~/.config/gitcafe/token`; a `CAFE_TOKEN` env var overrides it).
    - Use `cafe` — never `gh` — for forge operations against gitcafe.dev:
      PRs, issues, repos, branches (including the gitcafe/gitcafe repo itself).
    - Pass `--repo owner/name` explicitly (or run from a clone whose origin is
      gitcafe.dev); add `--json` for machine-readable output.
    - Examples:
      - `cafe pr list --repo gitcafe/gitcafe --json`
      - `cafe pr view 105 --repo gitcafe/gitcafe --json`
      - `cafe pr create --repo gitcafe/gitcafe --head <branch> --base main --title "..." --body "..."`
      - `cafe pr edit 105 --repo gitcafe/gitcafe --title "..." --body "..."`
      - `cafe pr comment 105 --repo gitcafe/gitcafe --body "..."`
      - `cafe issue create --repo gitcafe/gitcafe --title "..." --body "..."`
      - `cafe issue list --repo gitcafe/gitcafe --json`
    - If auth fails (401), the token file is missing or expired — tell the
      user instead of starting a device-flow login.
    - Never print, commit, or paste the token anywhere.

    # Git Rules

    - You may be in a dirty git worktree.
    - Never revert, reset, delete, or overwrite changes you did not make unless the user explicitly asks.
    - Before committing, inspect `git status`, `git diff`, and recent commits.
    - Stage only intended files and never stage secrets.
    - Commit, amend, push, or create PRs only when explicitly requested.
    - Prefer non-interactive git commands.
    - If hooks or checks fail, fix the issue and create a new commit rather than amending unless the user asked for amend.
  '';

  programs.bash = {
    enable = true;
    initExtra = ''
      umask 0002
    '';
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "devbox agent";
      user.email = "agent@devbox";
      safe.directory = "*";
    };
  };
}
