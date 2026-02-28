import { assert, assertEquals, nixEval, nixEvalJson, CFG } from "./helpers.ts";

Deno.test("networkmanager enabled", async () => {
  assertEquals(await nixEval(`${CFG}.networking.networkmanager.enable`), "true");
});

Deno.test("firewall enabled", async () => {
  assertEquals(await nixEval(`${CFG}.networking.firewall.enable`), "true");
});

Deno.test("Mihomo in trusted interfaces", async () => {
  const ifaces = await nixEvalJson(`${CFG}.networking.firewall.trustedInterfaces`) as string[];
  assert(ifaces.includes("Mihomo"), "Mihomo not in trustedInterfaces");
});

Deno.test("IP forwarding enabled for TUN", async () => {
  const fwd = await nixEval(`${CFG}.boot.kernel.sysctl."net.ipv4.ip_forward"`);
  assertEquals(fwd, "1");
});

Deno.test("system nameservers point to localhost", async () => {
  const ns = await nixEvalJson(`${CFG}.networking.nameservers`) as string[];
  assert(ns.includes("127.0.0.1"));
});
