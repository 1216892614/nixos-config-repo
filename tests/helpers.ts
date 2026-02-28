import { assert, assertEquals } from "jsr:@std/assert";
export { assert, assertEquals };

export async function run(cmd: string[]): Promise<{ code: number; stdout: string; stderr: string }> {
  const p = new Deno.Command(cmd[0], { args: cmd.slice(1), stdout: "piped", stderr: "piped" });
  const { code, stdout, stderr } = await p.output();
  return { code, stdout: new TextDecoder().decode(stdout), stderr: new TextDecoder().decode(stderr) };
}

export async function nixEval(expr: string): Promise<string> {
  const { code, stdout, stderr } = await run([
    "docker", "compose", "-f", "docker-compose.yml", "run", "--rm", "nix-check",
    "nix", "eval", "--raw", `/config#${expr}`,
  ]);
  if (code !== 0) throw new Error(`nix eval failed: ${stderr}`);
  return stdout.trim();
}

export async function nixEvalJson(expr: string): Promise<unknown> {
  const { code, stdout, stderr } = await run([
    "docker", "compose", "-f", "docker-compose.yml", "run", "--rm", "nix-check",
    "nix", "eval", "--json", `/config#${expr}`,
  ]);
  if (code !== 0) throw new Error(`nix eval failed: ${stderr}`);
  return JSON.parse(stdout.trim());
}

export async function fileExists(path: string): Promise<boolean> {
  try { const s = await Deno.stat(path); return s.isFile; } catch { return false; }
}

export async function readFile(path: string): Promise<string> {
  return await Deno.readTextFile(path);
}

const CFG = "nixosConfigurations.desktop.config";
const HM = `${CFG}.home-manager.users.ep-o1`;
export { CFG, HM };
