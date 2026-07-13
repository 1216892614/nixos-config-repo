{ stdenv, lib, fetchurl }:

stdenv.mkDerivation rec {
  pname = "omp";
  version = "16.4.8";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
    sha256 = "0k44hqgrcxzp8anb8r58y3nvxh1zri1favb0vbwn73dq0mg7gw6d";
  };

  dontUnpack = true;

  # Bun standalone binaries have JS bytecode appended after the ELF.
  # Strip and patchelf corrupt the appended data. The system's nix-ld
  # provides /lib64/ld-linux-x86-64.so.2, so no patching needed.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/omp
    chmod +x $out/bin/omp
  '';

  meta = with lib; {
    description = "oh-my-pi: AI coding agent for the terminal";
    homepage = "https://omp.sh";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "omp";
  };
}
