{ pkgs
, lib
, ...
}:
let
  # Same auto-discovery pattern as modules/home-manager/llm. Skills here
  # merge with the shared ones via attrset merging in nix's module system.
  discoverSkills = dir:
    lib.mapAttrs (name: _: dir + "/${name}")
      (lib.filterAttrs (_: v: v == "directory") (builtins.readDir dir));

  # TODO: re-enable once CI can evaluate this without a VPN. The
  # internal King marketplace lives behind github.int.midasplayer.com,
  # which isn't reachable from the public GitHub Actions runner that
  # runs `nix flake check` / `nix flake show` on every push. Possible
  # paths forward:
  #   - Gate the fetch on a CI env var (`builtins.getEnv "CI"`) and
  #     pass `--impure` from the workflow.
  #   - Scope CI to outputs that don't need VPN and lose check coverage
  #     for the work home.
  #   - Keep the King marketplace mutable (interactive
  #     `/plugin marketplace add`) and only nix-manage public stuff.
  #
  # ai-engineering-marketplace = builtins.fetchGit {
  #   url = "ssh://git@github.int.midasplayer.com/ai-ml/ai-engineering-marketplace.git";
  #   ref = "main";
  #   rev = "b1894daa569ea1b2cf0613393e3bafa6575d6834";
  # };
in
{
  programs.claude-code = {
    skills = discoverSkills ./skills;

    # marketplaces.ai-engineering = ai-engineering-marketplace;
    # plugins = [
    #   "${ai-engineering-marketplace}/plugins/git-worktree-create"
    # ];
  };
}
