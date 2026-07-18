{ pkgs
, fzf
, ripgrep
, git
, less
, ...
}:
pkgs.writeShellApplication {
  name = "fzf-git-blame";
  runtimeInputs = [
    fzf
    ripgrep
    git
    less
  ];
  text = builtins.readFile ./script.sh;
}
