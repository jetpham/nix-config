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
      system = "x86_64-linux";
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
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

      devShells.${system}.default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
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
    };
}
