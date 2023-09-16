{ config, pkgs, ... }: {
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    lfs = {
      enable = true;
      skipSmudge = true;
    };
    extraConfig = {
      init.defaultBranch = "main";
      pull.ff = "only";
      push.autoSetupRemote = true;
      core.editor = "vim";
    };
    userName = "John Pertoft";
    userEmail = "john.pertoft@gmail.com";
  };
}
