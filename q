[33mcommit 72e17f8ca37c1a0c711c6114cfc3cd06c59e29f9[m[33m ([m[1;36mHEAD[m[33m -> [m[1;32mmain[m[33m, [m[1;31morigin/main[m[33m)[m
Author: Jet Pham <55770902+jetpham@users.noreply.github.com>
Date:   Thu Mar 14 19:09:41 2024 -0700

    fixing warning

[1mdiff --git a/flake.lock b/flake.lock[m
[1mindex 177441e..d671653 100644[m
[1m--- a/flake.lock[m
[1m+++ b/flake.lock[m
[36m@@ -7,32 +7,32 @@[m
         ][m
       },[m
       "locked": {[m
[31m-        "lastModified": 1685599623,[m
[31m-        "narHash": "sha256-Tob4CMOVHue0D3RzguDBCtUmX5ji2PsdbQDbIOIKvsc=",[m
[32m+[m[32m        "lastModified": 1706981411,[m
[32m+[m[32m        "narHash": "sha256-cLbLPTL1CDmETVh4p0nQtvoF+FSEjsnJTFpTxhXywhQ=",[m
         "owner": "nix-community",[m
         "repo": "home-manager",[m
[31m-        "rev": "93db05480c0c0f30382d3e80779e8386dcb4f9dd",[m
[32m+[m[32m        "rev": "652fda4ca6dafeb090943422c34ae9145787af37",[m
         "type": "github"[m
       },[m
       "original": {[m
         "owner": "nix-community",[m
[31m-        "ref": "release-23.05",[m
[32m+[m[32m        "ref": "release-23.11",[m
         "repo": "home-manager",[m
         "type": "github"[m
       }[m
     },[m
     "nixpkgs": {[m
       "locked": {[m
[31m-        "lastModified": 1686431482,[m
[31m-        "narHash": "sha256-oPVQ/0YP7yC2ztNsxvWLrV+f0NQ2QAwxbrZ+bgGydEM=",[m
[32m+[m[32m        "lastModified": 1709703039,[m
[32m+[m[32m        "narHash": "sha256-6hqgQ8OK6gsMu1VtcGKBxKQInRLHtzulDo9Z5jxHEFY=",[m
         "owner": "nixos",[m
         "repo": "nixpkgs",[m
[31m-        "rev": "d3bb401dcfc5a46ce51cdfb5762e70cc75d082d2",[m
[32m+[m[32m        "rev": "9df3e30ce24fd28c7b3e2de0d986769db5d6225d",[m
         "type": "github"[m
       },[m
       "original": {[m
         "owner": "nixos",[m
[31m-        "ref": "nixos-23.05",[m
[32m+[m[32m        "ref": "nixos-unstable",[m
         "repo": "nixpkgs",[m
         "type": "github"[m
       }[m
[1mdiff --git a/flake.nix b/flake.nix[m
[1mindex d4eb038..f2544b4 100644[m
[1m--- a/flake.nix[m
[1m+++ b/flake.nix[m
[36m@@ -3,10 +3,10 @@[m
 [m
   inputs = {[m
     # Nixpkgs[m
[31m-    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";[m
[32m+[m[32m    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";[m
 [m
     # Home manager[m
[31m-    home-manager.url = "github:nix-community/home-manager/release-23.05";[m
[32m+[m[32m    home-manager.url = "github:nix-community/home-manager/release-23.11";[m
     home-manager.inputs.nixpkgs.follows = "nixpkgs";[m
 [m
     # TODO: Add any other flake you might need[m
[1mdiff --git a/home-manager/home.nix b/home-manager/home.nix[m
[1mindex 8251f04..0e13b11 100644[m
[1m--- a/home-manager/home.nix[m
[1m+++ b/home-manager/home.nix[m
[36m@@ -45,7 +45,7 @@[m
 [m
   xresources.properties = {[m
     "Xcursor.size" = 16;[m
[31m-    "Xft.dpi" = 172;[m
[32m+[m[32m    "Xft.dpi" = 200;[m
   };[m
 [m
   home.packages = with pkgs; [[m
[36m@@ -111,5 +111,4 @@[m
 [m
   # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion[m
   home.stateVersion = "23.05";[m
[31m-  programs.home-manager.enable = true;[m
 }[m
[1mdiff --git a/nixos/configuration.nix b/nixos/configuration.nix[m
[1mindex 2e109a0..dc9aa32 100644[m
[1m--- a/nixos/configuration.nix[m
[1m+++ b/nixos/configuration.nix[m
[36m@@ -14,7 +14,7 @@[m
   boot.loader.systemd-boot.enable = true;[m
   boot.loader.efi.canTouchEfiVariables = true;[m
 [m
[31m-  networking.hostName = "nixos"; # Define your hostname.[m
[32m+[m[32m  networking.hostName = "laptop"; # Define your hostname.[m
   # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.[m
 [m
   # Configure network proxy if necessary[m
[36m@@ -50,9 +50,9 @@[m
   services.xserver.desktopManager.plasma5.enable = true;[m
 [m
   # Configure keymap in X11[m
[31m-  services.xserver = {[m
[32m+[m[32m  services.xserver.xkb = {[m
     layout = "us";[m
[31m-    xkbVariant = "";[m
[32m+[m[32m    variant = "";[m
   };[m
 [m
   # Enable CUPS to print documents.[m
