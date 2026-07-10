{
  writeShellApplication,
  bun,
}:

# `cafe` — the gitcafe CLI, run from the /srv/dev/gitcafe checkout via bun.
#
# Deliberately NOT a sandboxed source build: the CLI is developed in that
# checkout and its workspace node_modules are already installed there, so the
# wrapper tracks the checkout instead of pinning a revision. Auth comes from
# an imperative token file (~/.config/gitcafe/token, chmod 0600) so the token
# never enters the nix store or this repo; CAFE_TOKEN in the environment
# still wins when set.
writeShellApplication {
  name = "cafe";
  runtimeInputs = [ bun ];
  text = ''
    cli="''${CAFE_CLI_SRC:-/srv/dev/gitcafe/services/cafe/src/index.ts}"
    if [ ! -f "$cli" ]; then
      echo "cafe: CLI source not found at $cli — clone gitcafe to /srv/dev/gitcafe (and bun install) or set CAFE_CLI_SRC" >&2
      exit 1
    fi

    token_file="''${CAFE_TOKEN_FILE:-''${XDG_CONFIG_HOME:-$HOME/.config}/gitcafe/token}"
    if [ -z "''${CAFE_TOKEN:-}" ] && [ -r "$token_file" ]; then
      CAFE_TOKEN="$(tr -d '[:space:]' < "$token_file")"
      export CAFE_TOKEN
    fi

    export CAFE_HOST="''${CAFE_HOST:-https://api.gitcafe.dev}"
    exec bun "$cli" "$@"
  '';
}
