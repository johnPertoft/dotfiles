{ pkgs
, ...
}:
{
  home.packages = with pkgs; [
    delve
    go
    go-tools
    gopls
  ];
}
