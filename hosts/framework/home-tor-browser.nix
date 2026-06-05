{ lib, pkgs, ... }:

let
  firefoxApplicationId = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
  firefoxAddons = pkgs.nur.repos.rycee.firefox-addons;
  # Extra Tor extensions reduce anonymity; keep this to the selected subset.
  torQolExtensions = with firefoxAddons; [
    bypass-paywalls-clean
    dearrow
    react-devtools
    return-youtube-dislikes
    sponsorblock
    translate-web-pages
    ublock-origin
    violentmonkey
    wappalyzer
    youtube-recommended-videos
  ];
  installTorExtension =
    addon:
    let
      xpi = "${addon}/share/mozilla/extensions/${firefoxApplicationId}/${addon.addonId}.xpi";
    in
    ''
      install -Dm444 "${xpi}" \
        "$out/share/tor-browser/distribution/extensions/${addon.addonId}.xpi"
      install -Dm444 "${xpi}" \
        "$out/share/tor-browser/TorBrowser/Data/Browser/profile.default/extensions/${addon.addonId}.xpi"
    '';
  torBrowser =
    (pkgs.tor-browser.override {
      extraPrefs = ''
        // Prefer Tor Browser's Safer mode by default without locking the UI.
        defaultPref("browser.security_level.security_slider", 2);
        defaultPref("browser.security_level.security_custom", false);
      '';
    }).overrideAttrs
      (old: {
        installPhase = (old.installPhase or "") + ''
          ${lib.concatMapStringsSep "\n" installTorExtension torQolExtensions}
        '';
      });
in
{
  home.packages = [ torBrowser ];
}
