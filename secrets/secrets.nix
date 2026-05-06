let
  sshPublicKeys = import ../ssh-public-keys.nix;
in

{
  "secrets/nasa-api.env.age".publicKeys = sshPublicKeys.jet;
}
