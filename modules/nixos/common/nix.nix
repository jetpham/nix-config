{ ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "jet"
    ];
    max-jobs = 4;
    cores = 6;
    build-users-group = "nixbld";
  };
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;

  programs.nix-index-database.comma.enable = true;
}
