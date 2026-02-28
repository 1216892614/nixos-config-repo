import { assert, assertEquals, run, nixEval } from "./helpers.ts";

Deno.test("flake check passes", async () => {
  const { code, stderr } = await run([
    "docker", "compose", "-f", "docker-compose.yml", "run", "--rm", "nix-check",
    "nix", "flake", "check", "--no-build", "/config",
  ]);
  assertEquals(code, 0, `flake check failed: ${stderr}`);
});

Deno.test("nixosConfigurations.desktop evaluates", async () => {
  const version = await nixEval("nixosConfigurations.desktop.config.system.stateVersion");
  assert(version.length > 0);
});
