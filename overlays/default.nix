{ inputs }:

[
  inputs.nur.overlays.default
  (final: prev: {
    betterbird = prev.callPackage ../pkgs/betterbird.nix { };

    # Qt's GTK file chooser aborts without GTK's GSettings schemas. Wrap the
    # cached package so both desktop apps can open files and library folders.
    yacreader = prev.symlinkJoin {
      name = prev.yacreader.name;
      paths = [ prev.yacreader ];
      nativeBuildInputs = [ prev.makeWrapper ];
      postBuild = ''
        for program in YACReader YACReaderLibrary YACReaderLibraryServer; do
          wrapProgram "$out/bin/$program" \
            --prefix XDG_DATA_DIRS : "${prev.gtk3}/share/gsettings-schemas/${prev.gtk3.name}"
        done
      '';
      inherit (prev.yacreader) meta;
    };

    # Staging snapshots are not guaranteed to have Hydra-built Chromium-family
    # packages yet. Use nixpkgs' ABI-identical upstream Electron binaries so
    # desktop apps do not trigger local Chromium rebuilds.
    electron_44 = prev.electron_44-bin;
    electron_45 = prev.electron_45-bin;

    chromedriver-bin = prev.stdenvNoCC.mkDerivation {
      pname = "chromedriver-bin";
      version = "157.0.8103.38";
      src = prev.fetchurl {
        url = "https://storage.googleapis.com/chrome-for-testing-public/157.0.8103.38/linux64/chromedriver-linux64.zip";
        hash = "sha256-MpUl+gvwK+GXlN4elHV3LvZGleBFbxQoiL1w3zFH3B4=";
      };
      nativeBuildInputs = [ prev.unzip ];
      sourceRoot = ".";
      installPhase = ''
        runHook preInstall
        install -Dm755 chromedriver-linux64/chromedriver $out/bin/chromedriver
        runHook postInstall
      '';
      inherit (prev.chromedriver) meta;
    };

    undetected-chromedriver = prev.undetected-chromedriver.override {
      chromedriver = final.chromedriver-bin;
    };

    # Google Chrome and Chrome for Testing publish the same version here. Keep
    # FlareSolverr's browser and patched driver in lockstep without compiling
    # Chromium from source on this staging revision.
    flaresolverr = prev.flaresolverr.override {
      chromium = final.google-chrome;
      undetected-chromedriver = final.undetected-chromedriver;
    };

    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (pythonFinal: pythonPrev: {
        show-in-file-manager = pythonPrev.show-in-file-manager.overrideAttrs (old: {
          # PyPI publishes this release with underscores in the archive name.
          src = prev.fetchPypi {
            pname = "show_in_file_manager";
            inherit (old) version;
            hash = "sha256-VZtZbj5WOADPadc0zSNoJCeanYINHYQWQMXxPgBY+bY=";
          };
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pythonFinal.hatchling
            pythonFinal.hatch-argparse-manpage
          ];
        });
      })
    ];
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

      # nixpkgs still packages v71, whose metadata stops at GNOME 50. Upstream
      # now carries the reviewed GNOME 51 port while preserving the same UUID
      # and settings schema, so existing clipboard history/preferences remain.
      clipboard-indicator = prev.gnomeExtensions.clipboard-indicator.overrideAttrs (_: {
        version = "72-unstable-2026-11-06";
        src = prev.fetchFromGitHub {
          owner = "Tudmotu";
          repo = "gnome-shell-extension-clipboard-indicator";
          rev = "60368b110c910b0aa9571f72717b43cc93d62e02";
          hash = "sha256-CMSQ4bPEfafHmrzFZXAMjDtbM8EZkSAl6Fs/fSwunNA=";
        };
      });

      # The source moved to a new UUID and already declares GNOME 49/50 support.
      tailscale-qs = prev.gnomeExtensions.tailscale-qs.overrideAttrs (old: {
        postInstall = "";
      });
    };

    codex =
      let
        # Codex publishes its rolling prerelease channel as alpha.
        version = "0.171.0-alpha.12";
        codeModeHostSrc = prev.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-xEO6UOGnYyGlcIY1+L5Lg0fz+zWK/Y4Z16rj5KSw/dw=";
        };
      in
      prev.stdenvNoCC.mkDerivation {
        pname = "codex";
        inherit version;
        src = prev.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-GpQelpXyoIIdqOlPPnwGEU1IY32Loii//zxu4UTGsaE=";
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

    pnpm_12_14 = prev.pnpm_11.overrideAttrs (_: {
      version = "12.14.0";
      src = prev.fetchurl {
        url = "https://registry.npmjs.org/pnpm/-/pnpm-12.14.0.tgz";
        hash = "sha256-6iBuNUdL+HvpVkqFynDtHI69xF2lWq+wo78J0bppsXk=";
      };
      # pnpm 12 no longer vendors native binaries in its npm archive.
      postUnpack = "";
      # Supply the native runner at build time so pnpm never downloads it
      # into the immutable store on first use.
      postPatch = ''
        tar -xOf ${
          prev.fetchurl {
            url = "https://registry.npmjs.org/@pnpm/exe.linux-x64-musl/-/exe.linux-x64-musl-12.14.0.tgz";
            hash = "sha256-YPMuv+gw3ESP4Xd+Aqd2UwwX8DpELY1rmbhv9ode0fA=";
          }
        } package/pnpm > pnpm-native
        chmod +x pnpm-native bin/pnpm.mjs bin/pnpx.mjs
      '';
    });

    t3code-unwrapped-nightly =
      (prev.t3code.unwrapped.override {
        # T3 targets Electron 44's published ABI. Use nixpkgs' official
        # upstream binary package while the GNOME 51 staging snapshot lacks a
        # cached source build; this avoids locally rebuilding all of Chromium.
        electron_44 = final.electron_44-bin;
        pnpm_12 = final.pnpm_12_14;
      }).overrideAttrs
        (
          finalAttrs: previousAttrs: {
            version = "0.1.11-nightly.20261118.4864";
            meta = previousAttrs.meta // {
              changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
            };
            nativeBuildInputs = previousAttrs.nativeBuildInputs ++ [ final.pkg-config ];
            buildInputs = (previousAttrs.buildInputs or [ ]) ++ [ final.libsecret ];
            src = final.fetchFromGitHub {
              owner = "pingdotgg";
              repo = "t3code";
              rev = "3e1b7c4e93d7f3d035d14296ebf45e373914ae8c";
              hash = "sha256-4Bvn4rOShrgeImIZl8of3ge2xXcc15uJ3PdTTohIgUk=";
            };
            pnpmDeps = previousAttrs.pnpmDeps.overrideAttrs (_: {
              pnpm_config_fetch_retries = 5;
              pnpm_config_fetch_timeout = 600000;
              pnpm_config_network_concurrency = 8;
              outputHash = "sha256-s/vm8Ox4o/AYpNC/amYP1KFWwh7SY5bCmVBuIJn9f/c=";
            });
            # SnapShots probes this bundle even when GNOME already has the
            # extension installed. The upstream Nix install phase omits it.
            postInstall = (previousAttrs.postInstall or "") + ''
              cp -r apps/desktop/gnome-extension "$out/libexec/t3code/apps/desktop/gnome-extension"
            '';
            # Upstream now handles development hosts explicitly. Apply the release
            # version before pnpm records the workspace state.
            postPatch = ''
              for packageJson in \
                apps/server/package.json \
                apps/desktop/package.json \
                apps/web/package.json \
                packages/contracts/package.json; do
                substituteInPlace "$packageJson" \
                  --replace-fail '"version": "0.1.10"' '"version": "${finalAttrs.version}"'
              done

              # Electron safeStorage derives its Linux keyring identity from the
              # product name. Keep the pre-Beta identity so existing encrypted
              # connection catalogs remain readable after the upstream rename.
              substituteInPlace apps/desktop/package.json \
                --replace-fail '"productName": "T3 Code (Beta)"' \
                               '"productName": "T3 Code (Alpha)"'

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
