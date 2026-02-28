import { assert, assertEquals, nixEval, CFG } from "./helpers.ts";

Deno.test("user ep-o1 exists", async () => {
  const shell = await nixEval(`${CFG}.users.users.ep-o1.shell`);
  assert(shell.includes("fish"));
});

Deno.test("ep-o1 in docker group", async () => {
  const groups = await nixEval(`builtins.toJSON ${CFG}.users.users.ep-o1.extraGroups`);
  assert(groups.includes("docker"));
});

Deno.test("openssh denies root login", async () => {
  assertEquals(await nixEval(`${CFG}.services.openssh.settings.PermitRootLogin`), "no");
});

Deno.test("openssh disables password auth", async () => {
  assertEquals(await nixEval(`${CFG}.services.openssh.settings.PasswordAuthentication`), "false");
});
