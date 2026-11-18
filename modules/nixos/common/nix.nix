{ config, ... }:

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
    options = "";
  };
  # Prune by count before collecting; nix-collect-garbage only accepts ages.
  systemd.services.nix-gc.preStart = ''
    ${config.nix.package}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +2
  '';
  nix.optimise.automatic = true;

  programs.nix-index-database.comma.enable = true;
}
