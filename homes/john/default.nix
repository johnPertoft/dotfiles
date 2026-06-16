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
    self.homeModules.fonts
    self.homeModules.fzf
    self.homeModules.git
    self.homeModules.github
    self.homeModules.home
    self.homeModules.kitty
    self.homeModules.llm
    self.homeModules.nix
    self.homeModules.tmux
    self.homeModules.editors.vim
    self.homeModules.editors.vscode
    self.homeModules.xdg
  ];
}
