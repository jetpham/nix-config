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
  };

  outputs = inputs@{
    self,
    nixpkgs,
    home-manager,
    nixos-hardware,
    ...
  }: {
    nixosConfigurations = {
      jet = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          nixos-hardware.nixosModules.framework-amd-ai-300-series
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.jet = import ./home.nix;
          }
          {
            nixpkgs.overlays = [
              (final: prev: {
                code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: rec {
                  pname = "cursor";
                  version = "2.0.64";
                  src = prev.appimageTools.extract {
                    inherit pname version;
                    src = prev.fetchurl {
                      url = "https://downloads.cursor.com/production/25412918da7e74b2686b25d62da1f01cfcd27683/linux/x64/Cursor-2.0.64-x86_64.AppImage";
                      hash = "sha256-zT9GhdwGDWZJQl+WpV2txbmp3/tJRtL6ds1UZQoKNzA=";
                    };
                  };
                  sourceRoot = "${pname}-${version}-extracted/usr/share/cursor";
                });
              })
            ];
          }
        ];
      };
    };
  };
}
