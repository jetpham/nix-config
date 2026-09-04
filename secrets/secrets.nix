let
  sshPublicKeys = import ../ssh-public-keys.nix;
in

{
  "secrets/devbox-aws.env.age".publicKeys = sshPublicKeys.jet ++ sshPublicKeys.devbox;
  "secrets/devbox-linear.env.age".publicKeys = sshPublicKeys.jet ++ sshPublicKeys.devbox;
  "secrets/nasa-api.env.age".publicKeys = sshPublicKeys.jet;
}
