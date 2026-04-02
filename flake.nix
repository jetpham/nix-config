{
  description = "flake for jet with Home Manager enabled";
  # https://github.com/drakerossman/nixos-musings/blob/main/how-to-add-home-manager-to-nixos/flake.nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-overlay = {
      url = "github:ryoppippi/claude-code-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }:
    {
      packages.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          t3Version = "0.0.15";
          t3App = pkgs.appimageTools.wrapType2 rec {
            pname = "t3";
            version = t3Version;

            src = pkgs.fetchurl {
              url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
              hash = "sha256:67ccbb4961f9e7e642edc469828d1c746dbbdeb6c38854b7a5742ddeea7bb038";
            };

            extraPkgs = pkgs: [ pkgs.xdg-utils ];
          };
          t3Icon = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/pingdotgg/t3code/v${t3Version}/apps/desktop/resources/icon.png";
            hash = "sha256-rXMAXnje7dOKxoqQ/G16Ohub9A54IPhhlv9x1/aKcvw=";
          };
          t3Desktop = pkgs.makeDesktopItem {
            name = "t3-code";
            desktopName = "T3 Code";
            genericName = "AI Coding Assistant";
            exec = "t3 %U";
            icon = "${t3Icon}";
            terminal = false;
            categories = [
              "Development"
              "IDE"
            ];
            startupNotify = true;
            comment = "Launch T3 Code from the GitHub release AppImage";
          };
        in
        {
          t3code = pkgs.symlinkJoin {
            name = "t3code-${t3Version}";
            paths = [
              t3App
              t3Desktop
            ];
          };
        };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      nixosConfigurations = {
        framework = nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            ./configuration.nix
            nixos-hardware.nixosModules.framework-amd-ai-300-series
            home-manager.nixosModules.home-manager
            inputs.nix-index-database.nixosModules.default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.jet = import ./home.nix;
            }
            {
              nixpkgs.overlays = [
                inputs.nur.overlays.default
                inputs.claude-code-overlay.overlays.default
              ];
            }
          ];
        };
      };

      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          nhs = pkgs.writeShellScriptBin "nhs" ''
            nh os switch --hostname framework path:. "$@"
          '';
        in
        pkgs.mkShell {
          packages = [
            pkgs.nh
            nhs
          ];
        };
    };
}
