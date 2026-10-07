{
  description = "flake for jet with Home Manager enabled";
  # https://github.com/drakerossman/nixos-musings/blob/main/how-to-add-home-manager-to-nixos/flake.nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    ghostty = {
      url = "github:ghostty-org/ghostty/main";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.home-manager.follows = "home-manager";
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
      nixos-hardware,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      androidPkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };
      androidComposition = androidPkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "36" "37.0" ];
        buildToolsVersions = [
          "37.0.0"
          "36.0.0"
          "35.0.0"
        ];
        includeCmake = true;
        cmakeVersions = [ "3.22.1" ];
        includeNDK = true;
        ndkVersions = [
          "27.1.12297006"
          "27.0.12077973"
        ];
      };
      androidSdkRoot = "${androidComposition.androidsdk}/libexec/android-sdk";
      buildT3codeMobile = androidPkgs.callPackage ./pkgs/t3code-mobile-build.nix {
        inherit androidSdkRoot;
      };
    in
    {
      formatter.${system} = pkgs.writeShellApplication {
        name = "nix-config-fmt";
        runtimeInputs = [
          pkgs.fd
          pkgs.nixfmt
        ];
        text = ''
          set -euo pipefail

          if [ "$#" -gt 0 ]; then
            exec nixfmt "$@"
          fi

          exec fd --extension nix --type f --hidden --exclude .git --exec-batch nixfmt
        '';
      };
      nixosConfigurations.framework = nixpkgs.lib.nixosSystem {
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/framework
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          home-manager.nixosModules.home-manager
          inputs.nix-index-database.nixosModules.default
          inputs.agenix.nixosModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
            home-manager.users.jet = import ./hosts/framework/home.nix;
          }
          {
            nixpkgs.overlays = import ./overlays { inherit inputs; };
          }
        ];
      };

      devShells.${system} = {
        default =
          let
            nhs = pkgs.writeShellScriptBin "nhs" ''
              sudo -v || exit $?
              nh os switch --hostname "$(${pkgs.hostname}/bin/hostname)" path:. "$@"
            '';
            nhb = pkgs.writeShellScriptBin "nhb" ''
              sudo -v || exit $?
              nh os boot --hostname "$(${pkgs.hostname}/bin/hostname)" path:. "$@"
            '';
          in
          pkgs.mkShell {
            packages = [
              pkgs.nh
              inputs.agenix.packages.${system}.default
              nhb
              nhs
            ];
          };

        t3code-android = androidPkgs.mkShell {
          packages = [
            androidComposition.androidsdk
            androidPkgs.corepack
            androidPkgs.curl
            androidPkgs.git
            androidPkgs.jdk17
            androidPkgs.nodejs_24
            buildT3codeMobile
          ];
          ANDROID_HOME = androidSdkRoot;
          ANDROID_SDK_ROOT = androidSdkRoot;
          ANDROID_NDK_ROOT = "${androidSdkRoot}/ndk/27.1.12297006";
          JAVA_HOME = "${androidPkgs.jdk17}";
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdkRoot}/build-tools/37.0.0/aapt2";
        };
      };
    };
}
