# Shared home-manager module set imported by every host. Per-host homes
# concatenate this with their own extras — see homes/<name>/default.nix.
# Kept as a flat list (not auto-discovered) so enabling a module stays an
# explicit, reviewable choice; hosts can also drop entries they don't want.
{ self
, system
, nix-index-database
, ...
}:
[
  nix-index-database.homeModules.nix-index
  self.homeModules.${system}
  self.homeModules.cloud
  self.homeModules.containers
  self.homeModules.data
  self.homeModules.fonts
  self.homeModules.home
  self.homeModules.llm
  self.homeModules.media
  self.homeModules.nix
  self.homeModules.security
  self.homeModules.utils
  self.homeModules.desktop.xdg
  self.homeModules.development.build
  self.homeModules.development.go
  self.homeModules.development.lint
  self.homeModules.development.node
  self.homeModules.development.python
  self.homeModules.development.rust
  self.homeModules.development.tools
  self.homeModules.editors.vim
  self.homeModules.editors.vscode
  self.homeModules.vcs.git
  self.homeModules.vcs.github
  self.homeModules.vcs.pijul
  self.homeModules.terminal.fzf
  self.homeModules.terminal.kitty
  self.homeModules.terminal.shell
  self.homeModules.terminal.tmux
]
