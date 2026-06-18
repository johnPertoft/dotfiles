# Grouping namespace for version control systems and their tooling. Each
# subdirectory is exposed as self.homeModules.vcs.<name> (git carries the
# git config + gitui + git CLI tools; github the gh CLI; pijul a separate
# DVCS).
import ../discover.nix ./.
