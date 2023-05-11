{ config, pkgs, lib, ... }: {
  programs.vim = {
    enable = true;
    settings = {
      mouse = "a";
      number = true;
      relativenumber = true;
      smartcase = true;
      ignorecase = true;
      copyindent = true;
    };
    plugins = with pkgs.vimPlugins; [
      nerdtree
      vim-airline
      vim-nix
    ];
  };
}