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
  modules = (import ../common.nix inputs) ++ [
    ./home.nix
    # Work laptop: extra host-scoped LLM/agent config (skills, etc.) layered
    # on top of the shared self.homeModules.llm pulled in by common.nix.
    ./llm.nix
  ];
}
