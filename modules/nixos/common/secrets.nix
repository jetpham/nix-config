{ ... }:

{
  age = {
    identityPaths = [ "/home/jet/.ssh/id_ed25519" ];
    secrets.nasa-api-env = {
      file = ../../../secrets/nasa-api.env.age;
      owner = "jet";
      group = "users";
      mode = "0400";
    };
  };
}
