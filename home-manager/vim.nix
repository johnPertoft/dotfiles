{ config, pkgs, lib, ... }: {
  programs.vim = {
    enable = true;
    settings = {
      mouse = "a";
      number = true;
      smartcase = true;
      ignorecase = true;
      copyindent = true;
    };
  };
}