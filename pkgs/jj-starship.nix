{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libgit2,
  zlib,
  versionCheckHook,
  withGit ? true,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "jj-starship";
  version = "0.7.1";

  src = fetchFromGitHub {
    owner = "dmmulroy";
    repo = "jj-starship";
    rev = "v${finalAttrs.version}";
    hash = "sha256-NLds7i1ZmscicaNLmkZCWmc7A+367BXxGioRd4yYof8=";
  };

  cargoHash = "sha256-i7x/y+BkKH+Xj1bU4RRe9fcteabB+4uAgJuW3x5/jv4=";
  buildNoDefaultFeatures = !withGit;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ zlib ] ++ lib.optionals withGit [ libgit2 ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Unified Starship prompt module for Git and Jujutsu repositories that is optimized for latency";
    homepage = "https://github.com/dmmulroy/jj-starship";
    changelog = "https://github.com/dmmulroy/jj-starship/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "jj-starship";
  };
})
