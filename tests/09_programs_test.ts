import { assertEquals, nixEval, HM, CFG } from "./helpers.ts";

Deno.test("fish shell enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.fish.enable`), "true");
});

Deno.test("kitty terminal enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.kitty.enable`), "true");
});

Deno.test("zellij enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.zellij.enable`), "true");
});

Deno.test("yazi enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.yazi.enable`), "true");
});

Deno.test("zed editor enabled with vim mode", async () => {
  assertEquals(await nixEval(`${HM}.programs.zed-editor.enable`), "true");
});

Deno.test("git enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.git.enable`), "true");
});

Deno.test("fzf enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.fzf.enable`), "true");
});

Deno.test("bat enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.bat.enable`), "true");
});

Deno.test("eza (ls replacement) enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.eza.enable`), "true");
});

Deno.test("fd enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.fd.enable`), "true");
});

Deno.test("ripgrep enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.ripgrep.enable`), "true");
});

Deno.test("zoxide enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.zoxide.enable`), "true");
});

Deno.test("direnv + nix-direnv enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.direnv.enable`), "true");
  assertEquals(await nixEval(`${HM}.programs.direnv.nix-direnv.enable`), "true");
});

Deno.test("btop enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.btop.enable`), "true");
});

Deno.test("obs-studio enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.obs-studio.enable`), "true");
});

Deno.test("starship prompt enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.starship.enable`), "true");
});

Deno.test("walker launcher enabled", async () => {
  assertEquals(await nixEval(`${HM}.programs.walker.enable`), "true");
});

Deno.test("external automount service configured", async () => {
  assertEquals(await nixEval(`${CFG}.systemd.services."external-automount@".serviceConfig.Type`), "oneshot");
});
