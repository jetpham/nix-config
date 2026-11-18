{ ... }:

{
  # emSign ECC Root CA - G3 is already absent from the upstream trust store.
  # Explicitly distrust the remaining root affected by the October 2026 compromise.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];
}
