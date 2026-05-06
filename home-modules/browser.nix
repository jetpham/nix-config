{ pkgs, ... }:

{
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
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
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
      search = {
        default = "SearXNG";
        privateDefault = "SearXNG";
        force = true;
        engines = {
          "SearXNG" = {
            urls = [ { template = "https://search.extremist.software/search?q={searchTerms}"; } ];
            definedAliases = [ "@s" ];
          };
        };
      };
    };
  };
}
