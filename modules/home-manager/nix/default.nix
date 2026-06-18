{ pkgs
, lib
, ...
}@inputs:
{
  # Add each flake input to the registry so `nix shell nixpkgs#...` and
  # friends resolve to the same pins this config is built from.
  nix.registry = (lib.mapAttrs (_: flake: { inherit flake; })) (
    (lib.filterAttrs (_: lib.isType "flake")) inputs
  );

  # Nix / home-manager workflow shortcuts.
  home.shellAliases = {
    edit = "nix edit";
    search = "nix search";
    update = "nix flake update --commit-lock-file";
    switch-home = "home-manager switch --flake .";
  };

  programs.nh.enable = true;

  home.packages = with pkgs; [
    cachix
    comma
    nil
    nix-diff
    nix-info
    nix-init
    nix-tree
    nixfmt
    nixos-rebuild
    nixpkgs-review
  ];
}
