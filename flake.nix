{
  description = "flake for jet with Home Manager enabled";
  # https://github.com/drakerossman/nixos-musings/blob/main/how-to-add-home-manager-to-nixos/flake.nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    ghostty.url = "github:ghostty-org/ghostty/main";
    helix.url = "github:helix-editor/helix/master";
    opencode.url = "github:anomalyco/opencode/dev";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      opencode,
      nixos-hardware,
      ...
    }:
    let
      mkHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            ./hosts/${hostname}
            nixos-hardware.nixosModules.framework-amd-ai-300-series
            home-manager.nixosModules.home-manager
            inputs.nix-index-database.nixosModules.default
            inputs.agenix.nixosModules.default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit inputs hostname;
              };
              home-manager.users.jet = import ./home.nix;
            }
            {
              nixpkgs.overlays = [
                inputs.nur.overlays.default
                inputs.ghostty.overlays.default
                inputs.helix.overlays.default
                opencode.overlays.default
                (final: prev: {
                  jj-starship = prev.callPackage ./pkgs/jj-starship.nix { };

                  # These nixpkgs packages still default to EOL Electron 39, but current builds work with Electron 40.
                  logseq = prev.logseq.override { electron_39 = prev.electron_40; };
                  zulip = prev.zulip.override { electron_39 = prev.electron_40; };

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
                  opencode-original = final.opencode;
                })
              ];
            }
          ];
        };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      nixosConfigurations = {
        framework = mkHost "framework";
        framework-work = mkHost "framework-work";
      };

      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          nhs = pkgs.writeShellScriptBin "nhs" ''
            sudo -v || exit $?
            nh os switch --hostname "$(${pkgs.hostname}/bin/hostname)" path:. "$@"
          '';
        in
        pkgs.mkShell {
          packages = [
            pkgs.nh
            inputs.agenix.packages.x86_64-linux.default
            nhs
          ];
        };
    };
}
