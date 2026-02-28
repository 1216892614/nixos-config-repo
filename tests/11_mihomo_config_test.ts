import { assert, readFile } from "./helpers.ts";

Deno.test("proxy.nix enables mihomo with TUN", async () => {
  const content = await readFile("../modules/nixos/proxy.nix");
  assert(content.includes("services.mihomo"));
  assert(content.includes("tunMode = true"));
});

Deno.test("proxy.nix fetches config from subscribe URL", async () => {
  const content = await readFile("../modules/nixos/proxy.nix");
  assert(content.includes("mihomoSubscribeUrl"));
  assert(content.includes("curl"));
});

Deno.test("proxy.nix has auto-update timer", async () => {
  const content = await readFile("../modules/nixos/proxy.nix");
  assert(content.includes("systemd.timers"));
  assert(content.includes("hourly") || content.includes("OnCalendar"));
});

Deno.test("proxy.nix configures firewall for TUN", async () => {
  const content = await readFile("../modules/nixos/proxy.nix");
  assert(content.includes("Mihomo"));
  assert(content.includes("trustedInterfaces"));
});

Deno.test("proxy.nix disables systemd-resolved", async () => {
  const content = await readFile("../modules/nixos/proxy.nix");
  assert(content.includes("services.resolved.enable = false"));
});

Deno.test("proxy.nix enables IP forwarding", async () => {
  const content = await readFile("../modules/nixos/proxy.nix");
  assert(content.includes("ip_forward"));
});
