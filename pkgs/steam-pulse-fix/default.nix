{ pkgs }:

let
  src = ./steam-pulse-fix.c;

  steamBootstrapper32BitPulseFix = pkgs.pkgsCross.gnu32.stdenv.mkDerivation {
    pname = "steam-pulse-fix-32";
    version = "1.1.0";
    inherit src;
    dontUnpack = true;
    dontMoveSlib = true;
    buildPhase = ''
      $CC -shared -fPIC -ldl -o steam_pulse_fix32.so $src
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp steam_pulse_fix32.so $out/lib/
    '';
  };

  steamWebHelper64BitPulseFix = pkgs.stdenv.mkDerivation {
    pname = "steam-pulse-fix-64";
    version = "1.1.0";
    inherit src;
    dontUnpack = true;
    dontMoveSlib = true;
    buildPhase = ''
      $CC -shared -fPIC -ldl -o steam_pulse_fix64.so $src
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp steam_pulse_fix64.so $out/lib/
    '';
  };
in
pkgs.symlinkJoin {
  name = "steam-pulse-fix-1.1.0";
  paths = [ steamBootstrapper32BitPulseFix steamWebHelper64BitPulseFix ];
  meta = {
    description = "LD_PRELOAD fix for Steam PulseAudio card info crash on PipeWire (32+64 bit)";
    platforms = [ "x86_64-linux" ];
  };
}
