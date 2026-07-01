# Moss & Fern v2 — forest dark theme with visible color separation
# Chromatic colors: HSL saturation raised to ~35-55% for real distinction
{
  bg         = "#1a1d1a";
  fg         = "#c8ccc0";
  line       = "#141714";
  selection  = "#2e322e";   # dark gray — subtle but visible selection on dark bg
  accent     = "#7fad6a";   # vivid green accent
  comment    = "#6b7265";   # muted grey-green
  gutter     = "#828a7a";   # visible gutter numbers

  keyword    = "#c78dda";   # purple — clear keyword pop
  func       = "#6bb8d6";   # sky blue — functions
  string     = "#a3c77d";   # leaf green — strings
  constant   = "#e0956c";   # warm orange — constants/numbers
  tag        = "#5cbdb9";   # teal — tags/labels
  entity     = "#5cbdb9";   # teal — types
  regexp     = "#6bbfa0";   # sea green — regex
  markup     = "#d48282";   # brick red — markup
  operator   = "#89c5a8";   # mint green — operators
  error      = "#e06c6c";   # clear red

  terminal = {
    bg            = "#1a1d1a";   # base
    fg            = "#e8ebe0";   # bright text — ensures reverse-video selection is obvious
    cursor        = "#e0ddd4";   # warm white
    black         = "#2e322e";   # surface1
    red           = "#d47272";
    green         = "#8fbf6a";
    yellow        = "#d4b86a";
    blue          = "#6ba4d4";
    magenta       = "#c78dda";   # vivid magenta
    cyan          = "#5cbdb9";   # teal
    white         = "#a8ada0";   # subtext1
    brightBlack   = "#4a4f48";   # surface2
    brightRed     = "#e08a8a";
    brightGreen   = "#a3d47d";
    brightYellow  = "#e0cc7d";
    brightBlue    = "#82b8e0";
    brightMagenta = "#da9ee8";
    brightCyan    = "#72d4cc";
    brightWhite   = "#c0c4b8";   # subtext0
  };

  added    = "#8fbf6a";   # green
  modified = "#6ba4d4";   # blue
  removed  = "#d47272";   # red

  surface = {
    sunk = "#141714";   # mantle — panels/sidebars
    base = "#1a1d1a";   # base — editor bg
    lift = "#242824";   # surface0 — active line, subtle hover
    over = "#2e322e";   # surface1 — borders, scrollbar
  };

  # UI semantic tokens
  bar = {
    bg     = "#0e100e";   # statusbar background
    fg     = "#d8dcd0";   # statusbar foreground
  };
  inactive = "#4a4f48";   # inactive borders/rings (surface2)
}
