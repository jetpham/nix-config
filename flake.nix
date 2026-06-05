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
      nixos-hardware,
      ...
    }:
    let
      hosts = import ./lib/hosts.nix;
      mkHost =
        hostname:
        let
          host = hosts.${hostname};
        in
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs hostname host;
          };
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
                inherit inputs hostname host;
              };
              home-manager.users.jet = import ./hosts/${hostname}/home.nix;
            }
            {
              nixpkgs.overlays = import ./overlays { inherit inputs; };
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
          nhb = pkgs.writeShellScriptBin "nhb" ''
            sudo -v || exit $?
            nh os boot --hostname "$(${pkgs.hostname}/bin/hostname)" path:. "$@"
          '';
        in
        pkgs.mkShell {
          packages = [
            pkgs.nh
            inputs.agenix.packages.x86_64-linux.default
            nhb
            nhs
          ];
        };
    };
}
