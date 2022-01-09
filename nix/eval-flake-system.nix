{ system, nixpkgs, home-manager, sops-nix, self, ... }:
systemConfiguration: nixpkgs.lib.nixosSystem {
  inherit system;

  modules = [
    systemConfiguration

    ./modules

    sops-nix.nixosModules.sops

    # Bootstrap home-manager
    ({ config, ... }: {
      _module.args.hmlib = home-manager.lib.hm;
      imports = [ home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.sharedModules =
        (import ./home-manager {
          inherit config;
          inherit (nixpkgs) lib;
        }).allModules;
    })

    # Fix flake registry inputs of the target derivation
    ({ lib, ... }: {
      nixpkgs.overlays = lib.optional (self ? overlay) self.overlay;
      # Let 'nixos-version --json' know the Git revision of this flake.
      system.configurationRevision = lib.mkIf (self ? rev) self.rev;
      nix.registry.p.flake = nixpkgs;
      nix.registry.nixpkgs.flake = nixpkgs;
    })
  ];
}
