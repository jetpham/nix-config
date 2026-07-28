{ ... }:

let
  devboxInstructions = ''
    # Devbox Context

    - This machine is `devbox`, a headless NixOS T3 Code host accessed through Tailscale.
    - T3 Code and its Codex and Claude providers run as `jet`.
    - Keep project work under `~/dev`.

    # Development Previews

    - Use an available TCP port from `5100-5199` for development previews.
    - Bind previews to `0.0.0.0` and report the URL as `http://devbox:<port>`.
    - Keep databases, debuggers, MCP servers, and other internal services on localhost.

    # NixOS Rules

    - Prefer declarative Nix configuration for persistent tools and services.
    - Treat a repository's `flake.nix` as the source of truth and use its dev shell.
    - Use `nix shell nixpkgs#<package>` for temporary tools when no project flake provides them.
    - Put clones, worktrees, generated repositories, and scratch work under `~/dev`, not `/tmp`.
    - Do not switch the NixOS configuration unless the user explicitly asks.
  '';
in

{
  home.username = "jet";
  home.homeDirectory = "/home/jet";
  home.stateVersion = "25.05";

  home.file.".claude/CLAUDE.md".text = devboxInstructions;
  home.file.".codex/AGENTS.md".text = devboxInstructions;

  programs.bash = {
    enable = true;
    initExtra = ''
      umask 0002
    '';
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Jet";
      user.email = "jet@extremist.software";
      safe.directory = "*";
    };
  };
}
