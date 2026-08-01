let
  sshPublicKeys = import ../ssh-public-keys.nix;
in

{
  "secrets/devbox-anthropic-api-key.age".publicKeys = sshPublicKeys.jet ++ sshPublicKeys.devbox;
  "secrets/devbox-aws.env.age".publicKeys = sshPublicKeys.jet ++ sshPublicKeys.devbox;
  "secrets/devbox-cafe.env.age".publicKeys = sshPublicKeys.jet ++ sshPublicKeys.devbox;
  "secrets/devbox-linear.env.age".publicKeys = sshPublicKeys.jet ++ sshPublicKeys.devbox;
  "secrets/devbox-openai-api-key.age".publicKeys = sshPublicKeys.jet ++ sshPublicKeys.devbox;
  "secrets/nasa-api.env.age".publicKeys = sshPublicKeys.jet;
}
