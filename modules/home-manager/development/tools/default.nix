{ pkgs
, ...
}:
{
  # Cross-cutting dev tools that don't belong to a single language:
  # CI runner, code indexer, runtime version manager.
  home.packages = with pkgs; [
    act
    asdf-vm
    ctags
  ];
}
