{ stdenv, lib, fetchurl }:

stdenv.mkDerivation rec {
  pname = "omp";
  version = "17.1.3";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
    sha256 = "0bj2m9p8p2f1jmrasp1z0mfm86mxvs6g9yr9kq90kg4wqkhy59qp";
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
