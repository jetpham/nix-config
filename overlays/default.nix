{ inputs }:

[
  inputs.nur.overlays.default
  inputs.ghostty.overlays.default
  (final: prev: {
    betterbird = prev.callPackage ../pkgs/betterbird.nix { };
    tea = prev.tea.overrideAttrs (
      finalAttrs: _: {
        version = "0.16.0";
        src = prev.fetchFromGitea {
          domain = "gitea.com";
          owner = "gitea";
          repo = "tea";
          tag = "v${finalAttrs.version}";
          hash = "sha256-wAs0L3UOwsyElrQ9n5BKV8rDZHzj42xL11HT1CFre8k=";
        };
        vendorHash = "sha256-QzJai1AmdXz5pYg1SEEFOetWJkkUhDZoQbJkhkz8UD4=";
      }
    );
    "configure-qbittorrent-tailscale" =
      prev.callPackage ../pkgs/configure-qbittorrent-tailscale.nix
        { };
    "qbittorrent-tailscale" = prev.callPackage ../pkgs/qbittorrent-tailscale.nix {
      configureQbittorrentTailscale = final."configure-qbittorrent-tailscale";
    };

    gnomeExtensions = prev.gnomeExtensions // {
      appindicator = prev.gnomeExtensions.appindicator.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace appIndicator.js \
            --replace-fail 'async _waitForFullyReady() {' $'async _waitForFullyReady() {\n        if (!this._indicator || !this._cancellable)\n            throw new GLib.Error(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED, "Indicator destroyed");'
        '';
      });

      # The source moved to a new UUID and already declares GNOME 49/50 support.
      tailscale-qs = prev.gnomeExtensions.tailscale-qs.overrideAttrs (old: {
        postInstall = "";
      });
    };

    codex =
      let
        # Codex publishes its rolling prerelease channel as alpha.
        version = "0.162.0-alpha.18";
        codeModeHostSrc = prev.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-vPjPH6YS5Dwrqj4atMSXm8tm/QHAQXIx2FpfzCKwq6c=";
        };
      in
      prev.stdenvNoCC.mkDerivation {
        pname = "codex";
        inherit version;
        src = prev.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-PWD1jTMCaXXMPiziFOKi1hSbWqyDiRf9Al2FOlXu8r0=";
        };
        sourceRoot = ".";
        nativeBuildInputs = [ prev.makeWrapper ];
        dontStrip = true;
        installPhase = ''
          runHook preInstall

          tar -xzf ${codeModeHostSrc}
          install -Dm755 codex-x86_64-unknown-linux-musl $out/libexec/codex
          install -Dm755 codex-code-mode-host-x86_64-unknown-linux-musl $out/libexec/codex-code-mode-host
          mkdir -p $out/bin
          ln -s ../libexec/codex-code-mode-host $out/bin/codex-code-mode-host
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

    pnpm_11_10 = prev.pnpm_11.overrideAttrs (_: {
      version = "11.10.0";
      src = prev.fetchurl {
        url = "https://registry.npmjs.org/pnpm/-/pnpm-11.10.0.tgz";
        hash = "sha256-YgtmBepPYvxWptCphzP0eQcdAyHgPkhrUix+mnRhdDE=";
      };
    });

    t3code-unwrapped-nightly =
      (prev.t3code.unwrapped.override {
        pnpm_11 = final.pnpm_11_10;
      }).overrideAttrs
        (
          finalAttrs: previousAttrs: {
            version = "0.0.46-nightly.20261007.2787";
            meta = previousAttrs.meta // {
              changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
            };
            nativeBuildInputs = previousAttrs.nativeBuildInputs ++ [ final.pkg-config ];
            buildInputs = (previousAttrs.buildInputs or [ ]) ++ [ final.libsecret ];
            src = final.fetchFromGitHub {
              owner = "pingdotgg";
              repo = "t3code";
              rev = "f570bd21663f56ce94c41829d3b7d72886e25a34";
              hash = "sha256-ljsdAbrJKwYVpK20ied7j/3VPpTIPexde6DsPsFKT3o=";
            };
            pnpmDeps = previousAttrs.pnpmDeps.overrideAttrs (_: {
              pnpm_config_fetch_retries = 5;
              pnpm_config_fetch_timeout = 600000;
              pnpm_config_network_concurrency = 8;
              outputHash = "sha256-4IE8MzK1AxYwd30YEn9R6XaVEr5XSFIWDdSh+X3Xdyw=";
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
                  --replace-fail '"version": "0.0.45"' '"version": "${finalAttrs.version}"'
              done

              # The license generator otherwise fetches SPDX data during the
              # sandboxed build. Use the exact revision expected by upstream.
              mkdir -p .generated/third-party-licenses/spdx/v3.28.0
              cp ${
                final.fetchFromGitHub {
                  owner = "spdx";
                  repo = "license-list-data";
                  rev = "c4a7237ec8f4654e867546f9f409749300f1bf4c";
                  hash = "sha256-FbeeEBAg9ih6DkAsXdU6ruZwkC7A2u2zYBvblpl54q0=";
                }
              }/json/details/*.json .generated/third-party-licenses/spdx/v3.28.0/
            '';
          }
        );

    # Keep the nightly native mobile client and server on the same protocol revision.
    t3code = prev.t3code.override {
      codex = final.codex;
      enableAzureDevOps = false;
      enableClaude = false;
      enableCodex = true;
      enableGit = true;
      enableGitHub = true;
      enableGitLab = true;
      enableJujutsu = false;
      enableOpencode = false;
      t3code-unwrapped = final.t3code-unwrapped-nightly;
    };
  })
]
