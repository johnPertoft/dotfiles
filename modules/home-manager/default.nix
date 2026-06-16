# Each subdirectory of this directory is exposed as self.homeModules.<name>.
# Grouping directories (editors, desktop, terminal) expose a nested attrset
# of their own subdirectories via the same discovery helper.
{ ... }:
import ./discover.nix ./.
