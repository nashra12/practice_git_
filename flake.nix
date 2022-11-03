{
  inputs = {
    # Quokka
    quokka-nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    quokka-hm.url = "github:nix-community/home-manager/release-22.05";
    quokka-hm.inputs.nixpkgs.follows = "quokka-nixpkgs";
    quokka-sops-nix.url = "github:Mic92/sops-nix";
    quokka-sops-nix.inputs.nixpkgs.follows = "quokka-nixpkgs";

    # Unstable
    unstable-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    unstable-hm.url = "github:nix-community/home-manager";
    unstable-hm.inputs.nixpkgs.follows = "unstable-nixpkgs";
    unstable-deploy-rs.url = "github:serokell/deploy-rs";
    unstable-deploy-rs.inputs.nixpkgs.follows = "unstable-nixpkgs";
    unstable-sops-nix.url = "github:Mic92/sops-nix";
    unstable-sops-nix.inputs.nixpkgs.follows = "unstable-nixpkgs";
    unstable-nur.url = "github:nix-community/NUR";

    # Agnostic
    flake-utils.url = "github:numtide/flake-utils";
    flake-registry.url = "github:NixOS/flake-registry";
    flake-registry.flake = false;
  };

  outputs = inputs@{ self, flake-utils, ... }: let
    # Distributions
    quokka = with inputs; {
      inherit (inputs) self flake-utils flake-registry;
      nixpkgs = quokka-nixpkgs;
      hm = quokka-hm;
      sops-nix = quokka-sops-nix;
    };
    unstable = with inputs; {
      inherit (inputs) self flake-utils flake-registry;
      nixpkgs = unstable-nixpkgs;
      hm = unstable-hm;
      deploy-rs = unstable-deploy-rs;
      sops-nix = unstable-sops-nix;
      nur = unstable-nur;
    };

    lib = unstable.nixpkgs.lib;

    mkSystem = dist: cfg:
      import ./nix/eval-flake-system.nix "x86_64-linux" dist cfg;

    vms = import ./nix/machines/vms.nix "x86_64-linux" unstable;

    forAllSystems = { self, nixpkgs, flake-utils, ... }: fn:
      lib.genAttrs flake-utils.lib.defaultSystems
        (s: fn (import nixpkgs { system = s; overlays = [ self.overlay ]; }));
  in {
    nixosConfigurations = vms // {
      Mimir = mkSystem unstable ./nix/machines/Mimir.nix;
      Mimir-vm = mkSystem quokka ({ modulesPath, ... }: {
        imports = [ ./nix/machines/Mimir.nix ./nix/modules/vm-compat.nix ];
      });
      Minerva = mkSystem quokka ./nix/machines/Minerva.nix;
      Heimdaalr = mkSystem quokka ./nix/machines/Heimdaalr.nix;
      strong-ghost = import ./nix/eval-flake-system.nix "aarch64-linux"
        quokka ./nix/machines/strong-ghost.nix;
    };

    apps = with lib; forAllSystems unstable (pkgs: with lib; let
      toApp = name: drv:
        { type = "app"; program = "${drv}/bin/run-${name}-vm"; };
      nixosConfigApps = mapAttrs
        (name: _: toApp name self.packages."${pkgs.system}"."${name}")
        self.nixosConfigurations;
    in nixosConfigApps);

    overlay = import ./software/overlay.nix;

    packages = forAllSystems unstable (pkgs: with lib; let
      overlayPackages = getAttrs (attrNames (self.overlay {} {})) pkgs;
      nixosConfigPackages = mapAttrs (_: c: c.config.system.build.vm)
        self.nixosConfigurations;
    in nixosConfigPackages // overlayPackages);

    devShells = forAllSystems quokka
      (pkgs: import ./nix/dev-shells.nix { inherit pkgs; });

    deploy = with self.nixosConfigurations; with unstable; {
      magicRollback = true;
      autoRollback = true;
      sshUser = "roosemberth";
      user = "root";

      nodes.Heimdaalr = {
        hostname = "Heimdaalr";
        profiles.system.path =
          deploy-rs.lib.x86_64-linux.activate.nixos Heimdaalr;
      };
      nodes.Mimir = {
        hostname = "Mimir";
        profiles.system.path =
          deploy-rs.lib.x86_64-linux.activate.nixos Mimir;
      };
      nodes.Minerva = {
        hostname = "Minerva";
        profiles.system.path =
          deploy-rs.lib.x86_64-linux.activate.nixos Minerva;
      };
    };
  };
}
