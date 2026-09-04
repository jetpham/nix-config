{ inputs }:

[
  inputs.nur.overlays.default
  inputs.ghostty.overlays.default
  inputs.opencode.overlays.default
  (final: prev: {
    betterbird = prev.callPackage ../pkgs/betterbird.nix { };
    "configure-qbittorrent-tailscale" =
      prev.callPackage ../pkgs/configure-qbittorrent-tailscale.nix
        { };
    jj-starship = prev.callPackage ../pkgs/jj-starship.nix { };
    linphone = prev.linphone.override {
      liblinphone = prev.linphonePackages.liblinphone.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/factory/factory.cpp \
            --replace-fail '#include <TextUtfEncoding.h>' '// TextUtfEncoding was removed in zxing-cpp 3.' \
            --replace-fail '#include <ZXing/TextUtfEncoding.h>' '// TextUtfEncoding was removed in zxing-cpp 3.' \
            --replace-fail 'writer.encode(ZXing::TextUtfEncoding::FromUtf8(code),' 'writer.encode(code,'
        '';
      });
    };
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
        postPatch = (old.postPatch or "") + ''
          substituteInPlace tailscale.js \
            --replace-fail 'if (this._cancelable.is_cancelled())' 'if (!this._cancelable || this._cancelable.is_cancelled())'
        '';
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

    codex =
      let
        version = "0.153.3";
        codeModeHostSrc = prev.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-EK5jMEXSjZ1dzWqnXYSYaOPOn+pu9OZp61HRJMaa71M=";
        };
      in
      prev.stdenvNoCC.mkDerivation {
        pname = "codex";
        inherit version;
        src = prev.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-b/lnS7AOFHNMJ0i8h4jqs8tuWsU+vefh54C07Xr0jLo=";
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
            version = "0.0.39-nightly.20260904.1280";
            nativeBuildInputs = previousAttrs.nativeBuildInputs ++ [ final.pkg-config ];
            buildInputs = (previousAttrs.buildInputs or [ ]) ++ [ final.libsecret ];
            src = final.fetchFromGitHub {
              owner = "pingdotgg";
              repo = "t3code";
              rev = "d6e29dc9dee943b34d6b0d11441fa944c7bff7c9";
              hash = "sha256-WG6IOSz/Ms85vVqqe1uiDPl6b/AM2cCn8gR2e/xWMmo=";
            };
            pnpmDeps = previousAttrs.pnpmDeps.overrideAttrs (_: {
              npm_config_fetch_retries = 5;
              npm_config_fetch_timeout = 600000;
              npm_config_network_concurrency = 8;
              outputHash = "sha256-mgRMeBpJmiTat38APyE4guNJ+6RiQhenphP7tRcmc+k=";
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
                  --replace-fail '"version": "0.0.38"' '"version": "${finalAttrs.version}"'
              done
            '';
          }
        );

    # Keep the nightly native mobile client and server on the same protocol revision.
    t3code = prev.t3code.override {
      codex = final.codex;
      enableAzureDevOps = true;
      enableClaude = false;
      enableCodex = true;
      enableGit = true;
      enableGitHub = true;
      enableGitLab = true;
      enableJujutsu = true;
      enableOpencode = true;
      opencode = final.opencode;
      t3code-unwrapped = final.t3code-unwrapped-nightly;
    };
  })
]
