import { assert, assertEquals, nixEval, nixEvalJson, CFG } from "./helpers.ts";

Deno.test("xdg portal enabled", async () => {
  assertEquals(await nixEval(`${CFG}.xdg.portal.enable`), "true");
});

Deno.test("NIXOS_OZONE_WL set for Wayland Electron", async () => {
  const val = await nixEval(`${CFG}.environment.sessionVariables.NIXOS_OZONE_WL`);
  assertEquals(val, "1");
});

Deno.test("GTK_USE_PORTAL set for file chooser", async () => {
  const val = await nixEval(`${CFG}.environment.sessionVariables.GTK_USE_PORTAL`);
  assertEquals(val, "1");
});

Deno.test("hardware graphics enabled", async () => {
  assertEquals(await nixEval(`${CFG}.hardware.graphics.enable`), "true");
});

Deno.test("v4l2loopback kernel module (virtual camera)", async () => {
  const mods = await nixEvalJson(`${CFG}.boot.kernelModules`) as string[];
  assert(mods.includes("v4l2loopback") || mods.includes("uvcvideo"));
});
