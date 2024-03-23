{
  description = "Jet's Nix Config";

  inputs = {
	nixpkgs.url = "nixpkgs/nixos-unstable";
	nixos-hardware.url = "github:NixOS/nixos-hardware";
	home-manager = {
		url = "github:nix-community/home-manager";
		inputs.nixpkgs.follows = "nixpkgs";
	};
  };

	# All outputs for the system (configs)
	outputs = { home-manager, nixpkgs, nixos-hardware, ... }@inputs: 
		let
			system = "x86_64-linux"; #current system
			pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
			lib = nixpkgs.lib;

			# This lets us reuse the code to "create" a system
			# Credits go to sioodmy on this one!
			# https://github.com/sioodmy/dotfiles/blob/main/flake.nix
			mkSystem = pkgs: system: hostname:
				let
					hardwareConfig = {
					"laptop" = "${inputs.nixos-hardware}.nixosModules.lenovo-thinkpad-x1-6th-gen";
					# Add other hostnames and their respective hardware configurations here
					};
				in
				pkgs.lib.nixosSystem {
					inherit system;
					modules = [
					{ networking.hostName = hostname; }
					./modules/system/configuration.nix
					(./. + "/hosts/${hostname}/hardware-configuration.nix")
					(hardwareConfig.${hostname} or (lib.mkForce {})) # Import hardware configuration if exists for hostname
					home-manager.nixosModules.home-manager
					{
						home-manager = {
						useUserPackages = true;
						useGlobalPkgs = true;
						extraSpecialArgs = { inherit inputs; };
						users.jet = (./. + "/hosts/${hostname}/user.nix");
						};
					}
					];
					specialArgs = { inherit inputs; };
				};


		in {
			nixosConfigurations = {
				# Now, defining a new system is can be done in one line
				#                                Architecture   Hostname
				laptop = mkSystem inputs.nixpkgs "x86_64-linux" "laptop";
				#desktop = mkSystem inputs.nixpkgs "x86_64-linux" "desktop";
			};
	};
}
