{ probeId, minimumBuildSeconds ? "300" }:
let
  minimum = builtins.fromJSON minimumBuildSeconds;
  flake = builtins.getFlake (toString ../.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  make = name: script: builtins.derivation {
    name = "${name}-${probeId}";
    system = "x86_64-linux";
    builder = "${pkgs.bash}/bin/bash";
    args = [ "-euc" script ];
  };
  slow = make "cache-probe" ''
    ${pkgs.coreutils}/bin/sleep ${toString (minimum + 10)}
    printf '%s\n' 'cache-probe-${probeId}' > "$out"
  '';
in
assert builtins.match "[0-9]+-[0-9]+" probeId != null;
assert builtins.isInt minimum && minimum > 0 && minimum <= 900;
# The slow dependency is eligible for caching; the cheap requested root is not.
make "cache-probe-root" ''
  printf '%s\n' '${slow}' > "$out"
''
