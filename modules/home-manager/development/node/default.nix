{ pkgs
, ...
}:
{
  home.packages = with pkgs; [
    nodejs
    yarn
    #nodePackages.npm
    #nodePackages.prettier
  ];
}
