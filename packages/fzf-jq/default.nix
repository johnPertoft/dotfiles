{ pkgs
, fzf
, jq
, less
, ...
}:
pkgs.writeShellApplication {
  name = "fzf-jq";
  runtimeInputs = [
    fzf
    jq
    less
  ];
  text = builtins.readFile ./script.sh;
}
