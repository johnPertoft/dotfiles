# Grouping namespace for development tooling: per-language toolchains
# (python/go/rust/node), plus linters, native-build tools, and assorted
# dev utilities. Each subdirectory is exposed as
# self.homeModules.development.<name> so homes opt in per piece.
import ../discover.nix ./.
