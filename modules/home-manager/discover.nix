# Auto-discover the immediate subdirectories of `dir` as an attrset
# mapping each subdirectory name to the module imported from it.
#
# Used both at the top level (modules/home-manager) and within grouping
# namespaces (editors, desktop, terminal) so dropping in a new module
# directory registers it automatically — there is no list to maintain.
# Pure builtins so it works without module args at the grouping level.
dir:
let
  entries = builtins.readDir dir;
  names = builtins.filter (name: entries.${name} == "directory") (
    builtins.attrNames entries
  );
in
builtins.listToAttrs (
  map (name: { inherit name; value = import (dir + "/${name}"); }) names
)
