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
    ./llm.nix
    nix-index-database.homeModules.nix-index
    self.homeModules.${system}
    self.homeModules.cloud
    self.homeModules.containers
    self.homeModules.fonts
    self.homeModules.git
    self.homeModules.github
    self.homeModules.home
    self.homeModules.llm
    self.homeModules.media
    self.homeModules.nix
    self.homeModules.desktop.xdg
    self.homeModules.editors.vim
    self.homeModules.editors.vscode
    self.homeModules.terminal.fzf
    self.homeModules.terminal.kitty
    self.homeModules.terminal.shell
    self.homeModules.terminal.tmux
  ];
}
