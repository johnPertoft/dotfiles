# Grouping namespace for editor modules. Each subdirectory is exposed as
# self.homeModules.editors.<name> so homes opt in per editor (e.g.
# cursor/zed are defined here but only enabled where wanted).
import ../discover.nix ./.
