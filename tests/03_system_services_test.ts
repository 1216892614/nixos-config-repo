import { assert, assertEquals, nixEval, nixEvalJson, CFG } from "./helpers.ts";

Deno.test("openssh enabled on port 22", async () => {
  assertEquals(await nixEval(`${CFG}.services.openssh.enable`), "true");
});

Deno.test("docker enabled", async () => {
  assertEquals(await nixEval(`${CFG}.virtualisation.docker.enable`), "true");
});

Deno.test("rustdesk service enabled", async () => {
  const wantedBy = await nixEvalJson(`${CFG}.systemd.services.rustdesk.wantedBy`) as string[];
  assert(wantedBy.includes("multi-user.target"), "rustdesk not wanted by multi-user.target");
  assertEquals(await nixEval(`${CFG}.systemd.services.rustdesk.serviceConfig.ExecStart`), `${await nixEval("nixosConfigurations.desktop.pkgs.rustdesk.outPath")}/bin/rustdesk --service`);
});

Deno.test("mihomo TUN mode enabled", async () => {
  assertEquals(await nixEval(`${CFG}.services.mihomo.tunMode`), "true");
  assertEquals(await nixEval(`${CFG}.services.mihomo.enable`), "true");
});

Deno.test("pipewire full stack enabled", async () => {
  assertEquals(await nixEval(`${CFG}.services.pipewire.enable`), "true");
  assertEquals(await nixEval(`${CFG}.services.pipewire.pulse.enable`), "true");
  assertEquals(await nixEval(`${CFG}.services.pipewire.alsa.enable`), "true");
  assertEquals(await nixEval(`${CFG}.services.pipewire.jack.enable`), "true");
});

Deno.test("bluetooth enabled", async () => {
  assertEquals(await nixEval(`${CFG}.hardware.bluetooth.enable`), "true");
});

Deno.test("udisks2 enabled", async () => {
  assertEquals(await nixEval(`${CFG}.services.udisks2.enable`), "true");
});

Deno.test("flatpak enabled", async () => {
  assertEquals(await nixEval(`${CFG}.services.flatpak.enable`), "true");
});

Deno.test("polkit enabled", async () => {
  assertEquals(await nixEval(`${CFG}.security.polkit.enable`), "true");
});

Deno.test("rtkit enabled for realtime audio", async () => {
  assertEquals(await nixEval(`${CFG}.security.rtkit.enable`), "true");
});

Deno.test("interception-tools caps2esc enabled", async () => {
  assertEquals(await nixEval(`${CFG}.services.interception-tools.enable`), "true");
});

Deno.test("opentabletdriver (wacom) enabled", async () => {
  assertEquals(await nixEval(`${CFG}.hardware.opentabletdriver.enable`), "true");
});

Deno.test("systemd-resolved disabled (mihomo DNS)", async () => {
  assertEquals(await nixEval(`${CFG}.services.resolved.enable`), "false");
});

Deno.test("niri compositor enabled", async () => {
  assertEquals(await nixEval(`${CFG}.programs.niri.enable`), "true");
});

Deno.test("fcitx5 input method enabled", async () => {
  assertEquals(await nixEval(`${CFG}.i18n.inputMethod.enable`), "true");
});
