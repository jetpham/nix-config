{
  description = "flake for jet with Home Manager enabled";
  # https://github.com/drakerossman/nixos-musings/blob/main/how-to-add-home-manager-to-nixos/flake.nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    opencode = {
      url = "github:anomalyco/opencode/dev";
    };
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
    t3code = {
      url = "github:Sawrz/t3code-nix";
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
      mkHost = hostname: nixpkgs.lib.nixosSystem {
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/${hostname}
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          home-manager.nixosModules.home-manager
          inputs.nix-index-database.nixosModules.default
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
              inputs.t3code.overlays.default
              (final: prev: {
                opencode = opencode.packages.${prev.stdenv.hostPlatform.system}.opencode;
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
            nhs
          ];
        };
    };
}
