import { assert, readFile } from "./helpers.ts";

Deno.test("hardware example contains NVIDIA config", async () => {
  const content = await readFile("../hosts/desktop/hardware-configuration.nix.example");
  assert(content.includes("nvidia"));
});

Deno.test("hardware example contains AMD config", async () => {
  const content = await readFile("../hosts/desktop/hardware-configuration.nix.example");
  assert(content.includes("amdgpu"));
});

Deno.test("hardware example has graphics.enable", async () => {
  const content = await readFile("../hosts/desktop/hardware-configuration.nix.example");
  assert(content.includes("hardware.graphics.enable"));
});
