{ config, pkgs, lib, self, ... }: {
    home.username = "john";
    home.homeDirectory = "/home/john";
    programs.git.userName = "John Pertoft";
    programs.git.userEmail = "john.pertoft@gmail.com";
#   imports = [
#     self.homeModules.vscode
#     self.homeModules.vim
#     self.homeModules.neovim
#     self.homeModules.emacs
#     self.homeModules.git
#     self.homeModules.packages
#   ];
}