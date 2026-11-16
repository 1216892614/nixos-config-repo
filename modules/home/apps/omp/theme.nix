colors:
{
    name = "moss-fern";
    vars = {
      accent = colors.accent;
      muted = colors.comment;
      bg = colors.terminal.bg;
      fg = colors.fg;
      surface = colors.surface.lift;
      border = colors.surface.over;
    };
    colors = {
      accent = "accent";
      border = "border";
      borderAccent = "accent";
      borderMuted = "muted";
      success = colors.added;
      error = colors.error;
      warning = colors.terminal.yellow;
      muted = "muted";
      dim = colors.inactive;
      text = "";
      thinkingText = "muted";

      selectedBg = colors.selection;
      userMessageBg = colors.terminal.bg;
      userMessageText = "";
      customMessageBg = colors.surface.lift;
      customMessageText = "";
      customMessageLabel = "accent";
      toolPendingBg = colors.terminal.bg;
      toolSuccessBg = "#1a2d1f";
      toolErrorBg = "#2d1a1f";
      toolTitle = "";
      toolOutput = "muted";

      statusLineBg = colors.terminal.bg;
      statusLineSep = colors.inactive;
      statusLineModel = colors.keyword;
      statusLinePath = colors.func;
      statusLineGitClean = colors.added;
      statusLineGitDirty = colors.terminal.yellow;
      statusLineContext = colors.tag;
      statusLineSpend = colors.func;
      statusLineStaged = colors.added;
      statusLineDirty = colors.terminal.yellow;
      statusLineUntracked = colors.error;
      statusLineOutput = colors.fg;
      statusLineCost = colors.constant;
      statusLineSubagents = colors.keyword;

      mdHeading = "accent";
      mdLink = colors.func;
      mdLinkUrl = "muted";
      mdCode = colors.terminal.fg;
      mdCodeBlock = colors.terminal.fg;
      mdCodeBlockBorder = "muted";
      mdQuote = "muted";
      mdQuoteBorder = "muted";
      mdHr = "muted";
      mdListBullet = "accent";

      toolDiffAdded = colors.added;
      toolDiffRemoved = colors.removed;
      toolDiffContext = "muted";

      syntaxComment = colors.comment;
      syntaxKeyword = colors.keyword;
      syntaxFunction = colors.func;
      syntaxVariable = colors.fg;
      syntaxString = colors.string;
      syntaxNumber = colors.constant;
      syntaxType = colors.entity;
      syntaxOperator = colors.operator;
      syntaxPunctuation = colors.gutter;

      thinkingOff = colors.inactive;
      thinkingMinimal = colors.comment;
      thinkingLow = colors.func;
      thinkingMedium = colors.tag;
      thinkingHigh = colors.keyword;
      thinkingXhigh = colors.error;

      bashMode = colors.tag;
      pythonMode = colors.keyword;
    };
    symbols = {
      preset = "nerd";
    };
}
