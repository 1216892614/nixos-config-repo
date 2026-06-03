import { assert, assertEquals, nixEval, nixEvalJson, CFG } from "./helpers.ts";

Deno.test("networkmanager enabled", async () => {
  assertEquals(await nixEval(`${CFG}.networking.networkmanager.enable`), "true");
});

Deno.test("firewall enabled", async () => {
  assertEquals(await nixEval(`${CFG}.networking.firewall.enable`), "true");
});

Deno.test("RustDesk ports opened", async () => {
  const tcp = await nixEvalJson(`${CFG}.networking.firewall.allowedTCPPorts`) as number[];
  const udp = await nixEvalJson(`${CFG}.networking.firewall.allowedUDPPorts`) as number[];
  for (const port of [21114, 21115, 21116, 21117, 21118, 21119]) {
    assert(tcp.includes(port), `RustDesk TCP ${port} not open`);
  }
  assert(udp.includes(21116), "RustDesk UDP 21116 not open");
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
