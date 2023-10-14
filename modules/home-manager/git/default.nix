{ config, pkgs, ... }: {
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    aliases = {
      s = "status";
      l = "log";
      d = "diff";
    };
    lfs = {
      enable = true;
      skipSmudge = true;
    };
    extraConfig = {
      core.editor = "vim";
      init.defaultBranch = "main";
      pull.ff = "only";
      push.autoSetupRemote = true;
    };
  };
}
