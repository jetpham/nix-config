{ inputs }:

[
  inputs.nur.overlays.default
  inputs.ghostty.overlays.default
  inputs.helix.overlays.default
  inputs.opencode.overlays.default
  (final: prev: {
    betterbird = prev.callPackage ../pkgs/betterbird.nix { };
    cafe-cli = prev.callPackage ../pkgs/cafe-cli.nix { };
    "configure-qbittorrent-tailscale" =
      prev.callPackage ../pkgs/configure-qbittorrent-tailscale.nix
        { };
    jj-starship = prev.callPackage ../pkgs/jj-starship.nix { };
    "qbittorrent-tailscale" = prev.callPackage ../pkgs/qbittorrent-tailscale.nix {
      configureQbittorrentTailscale = final."configure-qbittorrent-tailscale";
    };

    gnomeExtensions = prev.gnomeExtensions // {
      # The source moved to a new UUID and already declares GNOME 49/50 support.
      tailscale-qs = prev.gnomeExtensions.tailscale-qs.overrideAttrs (_: {
        postInstall = "";
      });
    };

    # opencode's dev branch asks for Bun 1.3.14, but this revision builds and runs with nixpkgs' Bun 1.3.13.
    opencode = prev.opencode.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace package.json \
          --replace-fail "bun@1.3.14" "bun@1.3.13"
        substituteInPlace packages/ui/package.json \
          --replace-fail '"./v2/*": "./src/v2/components/*.tsx",' '"./v2/*": "./src/v2/components/*.tsx", "./v2/*.css": "./src/v2/components/*.css",'
      '';
    });

    codex = prev.stdenvNoCC.mkDerivation {
      pname = "codex";
      version = "0.146.0";
      src = prev.fetchurl {
        url = "https://github.com/openai/codex/releases/download/rust-v0.146.0/codex-x86_64-unknown-linux-musl.tar.gz";
        hash = "sha256-W6O5QFVDlTCB9mHQhU0mb3biq75R1BNJNVo23nZzd2o=";
      };
      sourceRoot = ".";
      nativeBuildInputs = [ prev.makeWrapper ];
      dontStrip = true;
      installPhase = ''
        runHook preInstall

        install -Dm755 codex-x86_64-unknown-linux-musl $out/libexec/codex
        makeWrapper $out/libexec/codex $out/bin/codex \
          --prefix PATH : ${
            prev.lib.makeBinPath [
              prev.bubblewrap
              prev.ripgrep
            ]
          }

        runHook postInstall
      '';
      inherit (prev.codex) meta;
    };

    claude-code = prev.claude-code.overrideAttrs (_: {
      version = "2.1.220";
      src = prev.fetchurl {
        url = "https://downloads.claude.ai/claude-code-releases/2.1.220/linux-x64/claude";
        hash = "sha256-Z09h8g/zBvMQDPkgDkw2xLcCeLW+8ohFSYGblCqJyGM=";
      };
    });

    pnpm_11_10 = prev.pnpm_11.overrideAttrs (_: {
      version = "11.10.0";
      src = prev.fetchurl {
        url = "https://registry.npmjs.org/pnpm/-/pnpm-11.10.0.tgz";
        hash = "sha256-YgtmBepPYvxWptCphzP0eQcdAyHgPkhrUix+mnRhdDE=";
      };
    });

    t3code-unwrapped-nightly =
      (prev.t3code.unwrapped.override {
        pnpm_10 = final.pnpm_11_10;
      }).overrideAttrs
        (
          finalAttrs: previousAttrs: {
            version = "0.0.34-nightly.20260810.1062";
            src = final.fetchFromGitHub {
              owner = "pingdotgg";
              repo = "t3code";
              rev = "a7b0366cbe1e9eabc9e37eb079a38f6b6691f999";
              hash = "sha256-nq9hstmAX833Jc5JUx87GhOMzugGwcQdwBPOfxKyOSQ=";
            };
            pnpmDeps = previousAttrs.pnpmDeps.overrideAttrs (_: {
              outputHash = "sha256-i/K5bj7CS7PGIX5hfayxAJ7ngNib92w3SDKGXTVWccA=";
            });
            # Upstream now handles development hosts explicitly. Apply the release
            # version before pnpm records the workspace state.
            postPatch = ''
              for packageJson in \
                apps/server/package.json \
                apps/desktop/package.json \
                apps/web/package.json \
                packages/contracts/package.json; do
                substituteInPlace "$packageJson" \
                  --replace-fail '"version": "0.0.33"' '"version": "${finalAttrs.version}"'
              done
            '';
          }
        );

    # Keep the nightly native mobile client and both servers on the same protocol revision.
    t3code = prev.t3code.override {
      claude-code = final.claude-code;
      codex = final.codex;
      enableClaude = true;
      enableCodex = true;
      enableGit = true;
      enableGitHub = true;
      enableJujutsu = true;
      enableOpencode = true;
      opencode = final.opencode;
      t3code-unwrapped = final.t3code-unwrapped-nightly;
    };
  })
]
