{ config, pkgs, lib, ... }: {
  programs.vim = {
    enable = true;
    packageConfigurable = pkgs.vim;
    plugins = with pkgs.vimPlugins; [
      nerdtree
      vim-airline
      vim-fugitive
      vim-nix
      vim-startify
      ctrlp
    ];
    settings = {
      copyindent = true;
      ignorecase = true;
      mouse = "a";
      number = true;
      relativenumber = true;
      smartcase = true;
    };
    extraConfig = ''
      let g:netrw_banner = 0
      let g:netrw_liststyle = 3
    '';
  };
}
