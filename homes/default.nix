{ home-manager, nixpkgs, nixpkgs-unstable, nix-index-database, system, self, ... }@inputs:
let
  overlays = [
    (final: prev:
      let
        pkgs = import nixpkgs-unstable {
          system = system;
          super = prev;
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
            "vscode"
            "vscode-extension-github-copilot"
            "vscode-extension-MS-python-vscode-pylance"
            "vscode-extension-ms-vscode-cpptools"
            "vscode-extension-ms-vscode-remote-remote-containers"
            "vscode-extension-ms-vscode-remote-remote-ssh"
            "vscode-extension-ms-vsliveshare-vsliveshare"
          ];
        };
      in
      {
        vscode = pkgs.vscode;
        vscode-extensions = pkgs.vscode-extensions;
      }
    )
    # TODO: How to do this?
    # (final: prev:
    #   {
    #     python311 = prev.python311.override {
    #       packageOverrides = py-final: py-prev: {
    #         jedi = py-prev.jedi.overrideAttrs (old: {
    #           doCheck = false;
    #           doInstallCheck = false;
    #         });
    #       };
    #     };
    #   }
    # )
  ];

  names = builtins.attrNames (builtins.readDir ./.);
  mkHome = name: home-manager.lib.homeManagerConfiguration {
    pkgs = import nixpkgs {
      inherit system;
      inherit overlays;
    };
    modules = [
      ./${name}/home.nix
      self.homeModules.home
      nix-index-database.hmModules.nix-index
    ];
    extraSpecialArgs = inputs;
  };
in
nixpkgs.lib.genAttrs names mkHome
