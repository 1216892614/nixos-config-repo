{ pkgs, ... }:

{
  # Use kmscon to replace default VTs — enables CJK rendering in TTY
  services.kmscon = {
    enable = true;
    hwRender = true;
    fonts = [{ name = "Sarasa Mono SC"; package = pkgs.sarasa-gothic; }];
    extraConfig = "font-size=14";
  };

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
      source-han-sans
      source-han-serif
      source-han-mono
      wqy_zenhei
      noto-fonts-color-emoji
    ];

    # Steam is sensitive to fontconfig defaults; rely on fontconfig fallback instead.
    fontDir.enable = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Sarasa UI SC" "Source Han Sans SC" "WenQuanYi Zen Hei" ];
        serif = [ "Source Han Serif SC" "Sarasa UI SC" ];
        monospace = [ "Sarasa Mono SC" "Source Han Mono SC" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
