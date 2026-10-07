{ homeLib, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = homeLib.name;
      user.email = homeLib.email;
      core.sshCommand = "ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3";
      core.compression = 6;
      pack.windowMemory = "256m";
      pack.packSizeLimit = "2g";
      pack.threads = 1;
      gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
    };
    signing = {
      key = homeLib.sshSigningKey;
      signByDefault = true;
      format = "ssh";
    };
  };

  home.file.".gitconfig".text = ''
    # Compatibility shim for tools that only read ~/.gitconfig.
    [include]
      path = ~/.config/git/config
  '';

  home.file.".config/git/allowed_signers".text = builtins.concatStringsSep "" (
    map (publicKey: "${homeLib.email} ${publicKey}\n") homeLib.sshPublicKeys
  );

}
