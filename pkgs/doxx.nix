{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "doxx";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "bgreenwell";
    repo = "doxx";
    rev = "v${version}";
    hash = "sha256-0+7R0kdCcw+PdX4UfYuacCv86nzJW+LgTVml9drGZXE=";
  };

  cargoHash = "sha256-Eix63WAxOdK4//WBDfAdqMrtHCM1VSepSy841hCndeI=";

  # test_renderer_creation 需要真实终端（检测宽度），沙箱中跳过
  doCheck = false;

  meta = with lib; {
    description = "Terminal document viewer for .docx files";
    homepage = "https://github.com/bgreenwell/doxx";
    license = licenses.mit;
    mainProgram = "doxx";
  };
}
