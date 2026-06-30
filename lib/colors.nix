# Moss & Fern — desaturated yellow-green dark theme
# Chromatic colors: HSL saturation ~10-18%, muted foggy aesthetic
{
  bg         = "#1c1f1c";
  fg         = "#b5b9ae";
  line       = "#161916";
  selection  = "#405545";   # muted green highlight — clearly distinct from bg
  accent     = "#8e9878";   # yellow-green grey
  comment    = "#686c62";   # overlay0
  gutter     = "#767a70";   # overlay1

  keyword    = "#867a93";   # dusty lavender
  func       = "#758891";   # steel grey
  string     = "#7e9070";   # sage grey
  constant   = "#937d87";   # mauve grey
  tag        = "#6f8b8b";   # teal grey
  entity     = "#6f8b8b";   # teal grey
  regexp     = "#6f8b82";   # sea grey
  markup     = "#957272";   # brick grey
  operator   = "#6f8b82";   # sea grey
  error      = "#957272";   # brick grey

  terminal = {
    bg            = "#1c1f1c";   # base
    fg            = "#b5b9ae";   # text
    cursor        = "#ccc8be";   # warm neutral
    black         = "#343734";   # surface1
    red           = "#a07575";
    green         = "#839970";
    yellow        = "#a09670";
    blue          = "#7590a0";
    magenta       = "#9a7d8a";   # mauve
    cyan          = "#709088";   # sea
    white         = "#9da196";   # subtext1
    brightBlack   = "#484b46";   # surface2
    brightRed     = "#ad8282";
    brightGreen   = "#90a67d";
    brightYellow  = "#ada37d";
    brightBlue    = "#829dab";
    brightMagenta = "#a78a97";
    brightCyan    = "#7d9d95";
    brightWhite   = "#aaaea3";   # subtext0
  };

  added    = "#839970";   # green
  modified = "#7590a0";   # blue
  removed  = "#a07575";   # red

  surface = {
    sunk = "#161916";   # mantle
    base = "#1c1f1c";   # base
    lift = "#262926";   # surface0
    over = "#343734";   # surface1
  };

  # UI semantic tokens
  bar = {
    bg     = "#0e100e";   # statusbar background
    fg     = "#d0d4ca";   # statusbar foreground
  };
  inactive = "#484b46";   # inactive borders/rings (surface2)
}
