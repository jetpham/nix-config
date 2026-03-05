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
  };

  outputs = inputs@{
    self,
    nixpkgs,
    home-manager,
    nixos-hardware,
    ...
  }: {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    nixosConfigurations = {
      framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
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
          nh os switch --hostname framework --impure path:. "$@"
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
