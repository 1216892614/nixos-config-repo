import { assert, nixEval } from "./helpers.ts";

Deno.test("home packages include expected software", async () => {
  const pkgList = await nixEval(
    `builtins.toJSON (map (p: p.pname or p.name or "unknown") nixosConfigurations.desktop.config.home-manager.users.ep-o1.home.packages)`
  );
  const expected = [
    "google-chrome", "code-cursor",
    "grim", "slurp", "satty", "wf-recorder", "wl-clipboard", "cliphist",
    "docker-buildx", "sccache",
    "cargo-edit", "cargo-watch",
    "python3", "pipx", "poetry",
    "nodejs", "pnpm", "deno", "bun",
    "clang", "gcc", "cmake",
    "jq", "sd", "dust", "duf", "httpie", "tokei", "tealdeer", "hyperfine",
    "wine", "winetricks", "p7zip", "v4l-utils", "pavucontrol",
  ];
  for (const pkg of expected) {
    assert(pkgList.toLowerCase().includes(pkg.toLowerCase()), `${pkg} not in home.packages`);
  }
});
