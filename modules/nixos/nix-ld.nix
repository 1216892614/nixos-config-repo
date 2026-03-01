# Allow non-Nix binaries (e.g. @cloudflare/workerd-linux-64 from npm) that expect
# /lib64/ld-linux-x86-64.so.2 to run on NixOS. Needed for diceshock dev (miniflare/workerd).
{
  programs.nix-ld.enable = true;
}
