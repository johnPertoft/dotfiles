# Grouping namespace for per-language developer toolchains (compiler /
# runtime + LSP + package manager + formatters). Each subdirectory is
# exposed as self.homeModules.lang.<name> so homes opt in per language.
# General native-build tools (gcc, cmake, gnumake, ninja) and
# cross-language tools (ctags) stay in the home catch-all.
import ../discover.nix ./.
