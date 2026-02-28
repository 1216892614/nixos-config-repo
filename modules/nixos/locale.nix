{ pkgs, ... }:

{
  time.timeZone = "Asia/Shanghai";

  i18n = {
    defaultLocale = "zh_CN.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  fonts = {
    packages = with pkgs; [
      sarasa-gothic
      nerd-fonts.symbols-only
      fira-code
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];

    fontconfig.defaultFonts = {
      sansSerif = [ "Sarasa UI SC" "Noto Sans CJK SC" ];
      serif = [ "Sarasa UI SC" "Noto Serif CJK SC" ];
      monospace = [ "Sarasa Mono SC" "Fira Code" "Symbols Nerd Font" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
