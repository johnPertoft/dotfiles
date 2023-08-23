{ pre-commit-hooks, system, ... }: {
  pre-commit-check = pre-commit-hooks.lib.${system}.run {
    src = ./.;
    hooks = {
        nixpkgs-fmt.enable = true;
        shellcheck.enable = true;
        shfmt.enable = true;
    };
  };
}