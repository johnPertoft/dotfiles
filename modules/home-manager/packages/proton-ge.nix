{ fetchurl, stdenv }:

stdenv.mkDerivation rec {
  pname = "proton-ge-custom";
  version = "GE-Proton8-22";

  src = fetchurl {
    url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${version}/${version}.tar.gz";
    sha256 = "JBS1CFdiOCKLWwavx/o+TFHUPFAA/wygrFcyO9SK9cc=";
  };

  installPhase = ''
    mkdir -p $out
    mv * $out/
  '';
}
