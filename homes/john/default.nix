{ home-manager
, nixpkgs
, nix-index-database
, system
, self
, ...
}@inputs:

home-manager.lib.homeManagerConfiguration {
  extraSpecialArgs = inputs;
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      self.overlays.nixpkgs-unstable
    ];
  };
  modules = [
    ./home.nix
    nix-index-database.homeModules.nix-index
    self.homeModules.${system}
    self.homeModules.cloud
    self.homeModules.containers
    self.homeModules.data
    self.homeModules.fonts
    self.homeModules.home
    self.homeModules.llm
    self.homeModules.media
    self.homeModules.misc
    self.homeModules.nix
    self.homeModules.security
    self.homeModules.utils
    self.homeModules.desktop.xdg
    self.homeModules.editors.vim
    self.homeModules.editors.vscode
    self.homeModules.lang.go
    self.homeModules.lang.node
    self.homeModules.lang.python
    self.homeModules.lang.rust
    self.homeModules.vcs.git
    self.homeModules.vcs.github
    self.homeModules.vcs.pijul
    self.homeModules.terminal.fzf
    self.homeModules.terminal.kitty
    self.homeModules.terminal.shell
    self.homeModules.terminal.tmux
  ];
}
