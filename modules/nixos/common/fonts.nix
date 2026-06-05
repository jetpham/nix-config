{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      atkinson-hyperlegible-next
      nerd-fonts.commit-mono
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      symbola
      unifont
      unifont_upper
    ];

    fontconfig = {
      allowBitmaps = false;
      useEmbeddedBitmaps = false;

      defaultFonts = {
        sansSerif = [
          "Atkinson Hyperlegible Next"
          "Noto Sans"
          "Noto Sans CJK JP"
          "Noto Sans CJK SC"
          "Noto Sans CJK TC"
          "Noto Sans CJK HK"
          "Noto Sans CJK KR"
          "Symbols Nerd Font"
          "Noto Color Emoji"
          "Symbola"
          "Unifont"
        ];
        serif = [
          "Noto Serif"
          "Noto Serif CJK JP"
          "Noto Serif CJK SC"
          "Noto Serif CJK TC"
          "Noto Serif CJK KR"
          "Noto Color Emoji"
          "Symbola"
          "Unifont"
        ];
        monospace = [
          "CommitMono Nerd Font"
          "Noto Sans Mono"
          "Noto Sans Mono CJK JP"
          "Symbols Nerd Font Mono"
          "Noto Color Emoji"
          "Unifont"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
