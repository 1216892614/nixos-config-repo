import { assert, nixEval, nixEvalJson, CFG } from "./helpers.ts";

Deno.test("timezone is Asia/Shanghai", async () => {
  const tz = await nixEval(`${CFG}.time.timeZone`);
  assert(tz.includes("Shanghai"));
});

Deno.test("fonts include sarasa-gothic", async () => {
  const pkgs = await nixEval(`builtins.toJSON (map (p: p.pname or p.name or "unknown") ${CFG}.fonts.packages)`);
  assert(pkgs.includes("sarasa"));
});

Deno.test("default monospace font includes Sarasa Mono", async () => {
  const mono = await nixEvalJson(`${CFG}.fonts.fontconfig.defaultFonts.monospace`) as string[];
  assert(mono.some((f: string) => f.includes("Sarasa")));
});
