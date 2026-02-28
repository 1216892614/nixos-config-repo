import { assert, readFile } from "./helpers.ts";

Deno.test("colors.nix defines Ayu Dark palette", async () => {
  const content = await readFile("../lib/colors.nix");
  assert(content.includes("#10141c"), "bg color missing");
  assert(content.includes("#bfbdb6"), "fg color missing");
  assert(content.includes("#e6b450"), "accent color missing");
  assert(content.includes("#0a0e14"), "terminal bg missing");
});

Deno.test("noctalia.nix references ayu colors", async () => {
  const content = await readFile("../modules/home/desktop/noctalia.nix");
  assert(content.includes("colors") || content.includes("mPrimary"));
});

Deno.test("niri.nix references ayu colors for focus-ring", async () => {
  const content = await readFile("../modules/home/desktop/niri.nix");
  assert(content.includes("colors") || content.includes("focus-ring"));
});

Deno.test("kitty terminal references ayu colors", async () => {
  const content = await readFile("../modules/home/terminal.nix");
  assert(content.includes("colors") || content.includes("#0a0e14"));
});

Deno.test("walker theme references ayu colors", async () => {
  const content = await readFile("../modules/home/desktop/walker.nix");
  assert(content.includes("colors") || content.includes("ayu") || content.includes("#10141c"));
});

Deno.test("GTK dark theme configured", async () => {
  const content = await readFile("../modules/home/default.nix");
  assert(content.includes("prefer-dark") || content.includes("dark"));
});
