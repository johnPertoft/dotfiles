{ pkgs, self, ... }: {
  type = "app";
  program = (pkgs.writeScript "update" ''
    set -exuo pipefail
    echo HELLO!
  '').outPath;
}
