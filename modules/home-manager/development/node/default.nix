{ pkgs
, ...
}:
{
  home.packages = with pkgs; [
    yarn
    #nodejs
    #nodePackages.npm
    #nodePackages.prettier
  ];
}
