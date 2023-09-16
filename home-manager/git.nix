{ config, pkgs, ... }: {
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    userName = "John Pertoft";
    userEmail = "john.pertoft@gmail.com";
    lfs = {
      enable = true;
      skipSmudge = true;
    };
    extraConfig = {
      init.defaultBranch = "main";
      pull.ff = "only";
      push.autoSetupRemote = true;
    };
  };
}
