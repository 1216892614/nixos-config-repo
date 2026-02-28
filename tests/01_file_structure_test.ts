import { assert, fileExists, readFile } from "./helpers.ts";

Deno.test("flake.nix exists", async () => assert(await fileExists("../flake.nix")));
Deno.test("lib/colors.nix exists", async () => assert(await fileExists("../lib/colors.nix")));
Deno.test("capture.sh exists", async () => assert(await fileExists("../scripts/capture.sh")));
Deno.test("proxy.nix exists", async () => assert(await fileExists("../modules/nixos/proxy.nix")));
Deno.test("hardware-configuration.nix.example exists", async () => assert(await fileExists("../hosts/desktop/hardware-configuration.nix.example")));
Deno.test("hosts/desktop/default.nix exists", async () => assert(await fileExists("../hosts/desktop/default.nix")));

Deno.test("all NixOS modules exist", async () => {
  const modules = [
    "boot", "networking", "locale", "users", "audio", "desktop",
    "proxy", "keyremap", "usb", "ssh", "docker", "ime", "flatpak", "nix-settings",
  ];
  for (const m of modules) assert(await fileExists(`../modules/nixos/${m}.nix`), `${m}.nix missing`);
});

Deno.test("all Home Manager modules exist", async () => {
  const files = [
    "default.nix", "terminal.nix", "zellij.nix", "yazi.nix", "recording.nix",
    "desktop/niri.nix", "desktop/noctalia.nix", "desktop/walker.nix",
    "shell/fish.nix", "dev/git.nix", "dev/zed.nix", "dev/languages.nix",
  ];
  for (const f of files) assert(await fileExists(`../modules/home/${f}`), `${f} missing`);
});

Deno.test(".gitignore ignores hardware-configuration.nix", async () => {
  const content = await readFile("../.gitignore");
  assert(content.includes("hardware-configuration.nix"));
});

Deno.test("capture.sh is executable shell script", async () => {
  const content = await readFile("../scripts/capture.sh");
  assert(content.startsWith("#!/"));
  assert(content.includes("walker"));
  assert(content.includes("grim"));
  assert(content.includes("wf-recorder"));
});
