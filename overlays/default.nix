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
            version = "0.0.30-nightly.20260729.938";
            src = final.fetchFromGitHub {
              owner = "pingdotgg";
              repo = "t3code";
              rev = "60af905e70c944228cb35a74fa50740ec4b2d1f7";
              hash = "sha256-8N/TbKjaeog5+fbFr1o/Hs0xgbJijsZigo2FdOFtMco=";
            };
            pnpmDeps = previousAttrs.pnpmDeps.overrideAttrs (_: {
              outputHash = "sha256-Qiwbg1EPjcVvt8YGc0YYP+1NbgBIxMkwIyTq5f3gtl4=";
            });
            # Upstream now handles local, tailnet, and LAN development hosts explicitly.
            postPatch = "";
            # Keep internal metadata at the source tree's declared version so
            # release preparation does not invalidate pnpm's offline state.
            preBuild =
              builtins.replaceStrings
                [
                  "node scripts/update-release-package-versions.ts ${finalAttrs.version}"
                ]
                [
                  "node scripts/update-release-package-versions.ts 0.0.29"
                ]
                previousAttrs.preBuild;
            # Electron can occasionally miss a Pong while the connection is otherwise active.
            postInstall = (previousAttrs.postInstall or "") + ''
              for rpcClient in "$out"/libexec/t3code/node_modules/.pnpm/effect@4.0.0-beta.78_*/node_modules/effect/dist/unstable/rpc/RpcClient.js; do
                substituteInPlace "$rpcClient" \
                  --replace-fail 'let recievedPong = true;' 'let missedPongs = 0;' \
                  --replace-fail 'recievedPong = true;' 'missedPongs = 0;' \
                  --replace-fail 'if (!recievedPong) return latch.open;' 'missedPongs += 1;' \
                  --replace-fail 'recievedPong = false;' 'if (missedPongs >= 3) return latch.open;' \
                  --replace-fail 'if (responses.length === 0) return;' 'if (responses.length === 0) return; pinger.reset();'
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
