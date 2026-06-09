{ lib
, rustPlatform
, pam
, howdy
}:

rustPlatform.buildRustPackage {
  pname = "pam-howdy-animated";
  version = "0.1.0";

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  buildInputs = [ pam ];

  # Inject howdy PAM module path at build time
  PAM_HOWDY_PATH = "${howdy}/lib/security/pam_howdy.so";

  postInstall = ''
    # Install as PAM module
    mkdir -p $out/lib/security
    mv $out/lib/libpam_howdy_animated.so $out/lib/security/pam_howdy_animated.so
  '';

  meta = with lib; {
    description = "PAM module wrapping howdy with camera-style terminal animation";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
