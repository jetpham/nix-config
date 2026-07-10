{ inputs }:

[
  inputs.nur.overlays.default
  inputs.ghostty.overlays.default
  inputs.helix.overlays.default
  inputs.opencode.overlays.default
  (final: prev: {
    betterbird = prev.callPackage ../pkgs/betterbird.nix { };
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
  })
]
