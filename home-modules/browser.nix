{ lib, pkgs, ... }:

let
  firefoxApplicationId = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
  firefoxAddons = pkgs.nur.repos.rycee.firefox-addons;
  zenQolExtensions = with firefoxAddons; [
    ublock-origin
    onepassword-password-manager
    sponsorblock
    youtube-recommended-videos
    darkreader
    vimium
    return-youtube-dislikes
    react-devtools
    firefox-color
    pay-by-privacy
    bypass-paywalls-clean
    translate-web-pages
    user-agent-string-switcher
    wappalyzer
    control-panel-for-twitter
    copy-selected-tabs-to-clipboard
    dearrow
    violentmonkey
    tst-indent-line
  ];
  # Extra Tor extensions reduce anonymity; keep this to the selected subset.
  torQolExtensions = with firefoxAddons; [
    ublock-origin
    sponsorblock
    youtube-recommended-videos
    return-youtube-dislikes
    dearrow
    translate-web-pages
    violentmonkey
    bypass-paywalls-clean
    react-devtools
    wappalyzer
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

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      DisableAppUpdate = true;
      DisableMasterPasswordCreation = true;
      DisablePasswordReveal = true;
      DisableProfileImport = true;
      ExtensionUpdate = false;
      OfferToSaveLogins = false;
      DisableFirefoxAccounts = true;
      DisableFormHistory = true;
      DisableSafeMode = true;
      DisableSetDesktopBackground = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      HardwareAcceleration = true;
      NoDefaultBookmarks = true;
      PasswordManagerEnabled = false;
      Preferences = {
        "zen.theme.border-radius" = 0;
        "zen.theme.content-element-separation" = 0;
      };
    };
    profiles.default = {
      isDefault = true;
      settings = {
        "identity.fxaccounts.enabled" = false;
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.suggest.searches" = false;
        "font.default.ja" = "sans-serif";
        "font.default.ko" = "sans-serif";
        "font.default.x-unicode" = "sans-serif";
        "font.default.x-western" = "sans-serif";
        "font.default.zh-CN" = "sans-serif";
        "font.default.zh-HK" = "sans-serif";
        "font.default.zh-TW" = "sans-serif";
        "font.name-list.emoji" = "Noto Color Emoji";
        "font.name.monospace.ja" = "Noto Sans Mono CJK JP";
        "font.name.monospace.ko" = "Noto Sans Mono CJK KR";
        "font.name.monospace.x-unicode" = "CommitMono Nerd Font";
        "font.name.monospace.x-western" = "CommitMono Nerd Font";
        "font.name.monospace.zh-CN" = "Noto Sans Mono CJK SC";
        "font.name.monospace.zh-HK" = "Noto Sans Mono CJK HK";
        "font.name.monospace.zh-TW" = "Noto Sans Mono CJK TC";
        "font.name.sans-serif.ja" = "Noto Sans CJK JP";
        "font.name.sans-serif.ko" = "Noto Sans CJK KR";
        "font.name.sans-serif.x-unicode" = "Atkinson Hyperlegible Next";
        "font.name.sans-serif.x-western" = "Atkinson Hyperlegible Next";
        "font.name.sans-serif.zh-CN" = "Noto Sans CJK SC";
        "font.name.sans-serif.zh-HK" = "Noto Sans CJK HK";
        "font.name.sans-serif.zh-TW" = "Noto Sans CJK TC";
        "font.name.serif.ja" = "Noto Serif CJK JP";
        "font.name.serif.ko" = "Noto Serif CJK KR";
        "font.name.serif.x-unicode" = "Noto Serif";
        "font.name.serif.x-western" = "Noto Serif";
        "font.name.serif.zh-CN" = "Noto Serif CJK SC";
        "font.name.serif.zh-HK" = "Noto Serif CJK HK";
        "font.name.serif.zh-TW" = "Noto Serif CJK TC";
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "ui.prefersReducedMotion" = 1;
        "zen.theme.border-radius" = 0;
        "zen.theme.content-element-separation" = 0;
        "zen.view.compact.show-sidebar-and-toolbar-on-hover" = true;
      };
      userChrome = ''
        @-moz-document url("chrome://browser/content/browser.xhtml") {
          @media -moz-pref("zen.view.compact.hide-toolbar") {
            :root[zen-compact-mode="true"]:not([customizing]):not([inDOMFullscreen="true"]):not([zen-single-toolbar="true"])
              #zen-appcontent-navbar-wrapper:not([has-popup-menu]):not([zen-compact-mode-active]) {
              pointer-events: none !important;
            }

            :root[zen-compact-mode="true"]:not([customizing]):not([inDOMFullscreen="true"]):not([zen-single-toolbar="true"])
              #zen-appcontent-navbar-wrapper[zen-has-hover]:not([has-popup-menu]):not([zen-compact-mode-active]) {
              height: var(--zen-element-separation) !important;
              overflow: clip !important;
            }

            :root[zen-compact-mode="true"]:not([customizing]):not([inDOMFullscreen="true"]):not([zen-single-toolbar="true"])
              #zen-appcontent-navbar-wrapper[zen-has-hover]:not([has-popup-menu]):not([zen-compact-mode-active])
              #urlbar:not([breakout-extend="true"]) {
              opacity: 0 !important;
              pointer-events: none !important;
            }

            :root[zen-compact-mode="true"]:not([customizing]):not([inDOMFullscreen="true"]):not([zen-single-toolbar="true"])
              #zen-appcontent-navbar-wrapper[zen-has-hover]:not([has-popup-menu]):not([zen-compact-mode-active])
              #zen-appcontent-navbar-container {
              opacity: 0 !important;
            }

            :root[zen-compact-mode="true"]:not([customizing]):not([inDOMFullscreen="true"]):not([zen-single-toolbar="true"])
              #zen-appcontent-navbar-wrapper[zen-has-hover]:not([has-popup-menu]):not([zen-compact-mode-active])
              .titlebar-buttonbox-container {
              max-height: 0 !important;
            }
          }
        }
      '';
      extensions.packages = zenQolExtensions;
      search = {
        default = "Local Google";
        privateDefault = "Local Google";
        force = true;
        engines = {
          "Local Google" = {
            urls = [ { template = "http://127.0.0.1:8888/search?q={searchTerms}"; } ];
            definedAliases = [ "@lg" ];
          };
          "Google Web" = {
            urls = [ { template = "https://www.google.com/search?q={searchTerms}&pws=0&udm=14"; } ];
            definedAliases = [ "@g" ];
          };
          "SearXNG" = {
            urls = [ { template = "https://search.extremist.software/search?q={searchTerms}"; } ];
            definedAliases = [ "@s" ];
          };
        };
      };
    };
  };
}
