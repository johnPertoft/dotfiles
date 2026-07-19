{ pkgs
, libarchive
, ...
}:
pkgs.writeShellApplication {
  name = "extract";
  runtimeInputs = [
    libarchive # provides bsdtar, auto-detects most archive formats
  ];
  text = builtins.readFile ./script.sh;
}
