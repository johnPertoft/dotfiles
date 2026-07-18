{ pkgs
, fzf
, kubectl
, gnused
, ...
}:
pkgs.writeShellApplication {
  name = "fzf-k8s";
  runtimeInputs = [
    fzf
    kubectl
    gnused
  ];
  text = builtins.readFile ./script.sh;
}
