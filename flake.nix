{
  inputs.nixpkgs-porcupine.url = "github:NixOS/nixpkgs/nixos-21.11";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";
  inputs.hm-porcupine.url = "github:nix-community/home-manager/release-21.11";
  inputs.hm-porcupine.inputs.nixpkgs.follows = "nixpkgs-porcupine";
  inputs.hm-unstable.url = "github:nix-community/home-manager";
  inputs.hm-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.deploy-rs.url = "github:serokell/deploy-rs";
  inputs.deploy-rs.inputs.nixpkgs.follows = "nixpkgs-unstable";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

  outputs = inputs@{
    self,
    nixpkgs-unstable,
    nixpkgs-porcupine,
    hm-porcupine,
    hm-unstable,
    flake-utils,
    deploy-rs,
    sops-nix,
  }:
  let
    mkFlakeSystem = flakes@{
      system ? "x86_64-linux",
      nixpkgs ? nixpkgs-porcupine,
      home-manager ? hm-porcupine,
      ...
    }: cfg: import ./nix/eval-flake-system.nix
      (inputs // { inherit system nixpkgs home-manager; }) cfg;

    forAllSystems = { nixpkgs ? nixpkgs-unstable }: fn:
      nixpkgs.lib.genAttrs
        flake-utils.lib.defaultSystems
        (sys: fn (import nixpkgs
          { system = sys; overlays = [ self.overlay ]; }));
  in {
    nixosConfigurations = {
      Mimir = mkFlakeSystem {
        nixpkgs = nixpkgs-unstable;
        home-manager = hm-unstable;
      } ./nix/machines/Mimir.nix;
      Mimir-vm = mkFlakeSystem {} ({ modulesPath, ... }: {
        imports = [ ./nix/machines/Mimir.nix ./nix/modules/vm-compat.nix ];
      });
      Minerva = mkFlakeSystem {} ./nix/machines/Minerva.nix;
      Heimdaalr = mkFlakeSystem {} ./nix/machines/Heimdaalr.nix;
      batman = mkFlakeSystem {} {
        _module.args.nixosSystem = nixpkgs-porcupine.lib.nixosSystem;
        _module.args.home-manager = hm-porcupine.nixosModules.home-manager;
        imports = [ ./nix/machines/tests/batman.nix ];
      };
    };

    apps = with nixpkgs-unstable.lib; (forAllSystems {} (pkgs: let
      toApp = name: drv: let host = removePrefix "vms/" name; in
        { type = "app"; program = "${drv}/bin/run-${host}-vm"; };
      isVm = name: _: hasPrefix "vms/" name;
      vmApps = mapAttrs toApp (filterAttrs isVm self.packages."${pkgs.system}");
    in vmApps));

    overlay = import ./nix/pkgs/overlay.nix;

    packages = (forAllSystems {} (pkgs: flake-utils.lib.flattenTree {
      vms = pkgs.lib.recurseIntoAttrs (import ./nix/machines/vms.nix {
        inherit pkgs;
        flakes = inputs // {
          nixpkgs = nixpkgs-unstable;
          home-manager = hm-unstable;
        };
      });
    } // (with nixpkgs-unstable.lib; getAttrs
              (attrNames (self.overlay {} {})) pkgs)));

    templates.generic.path = ./nix/flake-templates/generic;
    templates.generic.description = "Generic template for my projects.";

    defaultTemplate = self.templates.generic;
    devShells = forAllSystems { nixpkgs = nixpkgs-porcupine; }
      (pkgs: import ./nix/dev-shells.nix { inherit pkgs; });

    deploy = with self.nixosConfigurations; {
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
