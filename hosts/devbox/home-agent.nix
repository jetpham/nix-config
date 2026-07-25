{ ... }:

let
  agentInstructions = ''
    # Devbox Context

    - This machine is `devbox`, a headless NixOS T3 Code host accessed through Tailscale.
    - T3 Code and its Codex and Claude providers run as `agent`.
    - Keep project work under `/srv/dev`; `/home/jet` belongs to the interactive administrator.

    # Development Previews

    - Use an available TCP port from `5100-5199` for development previews.
    - Bind previews to `0.0.0.0` and report the URL as `http://devbox:<port>`.
    - Keep databases, debuggers, MCP servers, and other internal services on localhost.

    # NixOS Rules

    - Prefer declarative Nix configuration for persistent tools and services.
    - Treat a repository's `flake.nix` as the source of truth and use its dev shell.
    - Use `nix shell nixpkgs#<package>` for temporary tools when no project flake provides them.
    - Put clones, worktrees, generated repositories, and scratch work under `/srv/dev`, not `/tmp`.
    - Do not switch the NixOS configuration unless the user explicitly asks.
  '';
in

{
  home.username = "agent";
  home.homeDirectory = "/home/agent";
  home.stateVersion = "25.05";

  home.file.".claude/CLAUDE.md".text = agentInstructions;
  home.file.".codex/AGENTS.md".text = agentInstructions;

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
