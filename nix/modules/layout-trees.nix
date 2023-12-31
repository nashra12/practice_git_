{ config, pkgs, lib, ... }: with lib; let
  layout-tree-opts = with types; { name, ... }: {
    options.destination = mkOption {
      description = "Directory where to mount the 'layout tree' subvolumes.";
      default = name;
      type = str;
    };
    options.layout_tree = mkOption {
      description = ''
        Path to the layout tree. It should be inside the default btrfs subvolume.
      '';
      type = str;
    };
    options.tree_prefix = mkOption {
      description = ''
        Prefix where the layout tree is mounted. This prefix will be removed
        from path in the 'subvol' option in the mount units.
        Usually the mounting point of the root btrfs subvolume.
      '';
      type = str;
    };
    options.device_path = mkOption {
      description = "Path to the block device holding the root btrfs subvolme.";
      type = str;
    };
    options.extra_opts = mkOption {
      description = "Extra mount options to be applied in all mount units.";
      type = listOf str;
      default = [];
    };
  };
  cfg = config.roos.layout-trees;
in {
  options.roos.layout-trees = with types; {
    enable = mkEnableOption ''
      Enable generation of mount systemd mount units based on layout-trees.

      Example: Users may want to mount some subvolumes under their home
      directory before the session is started. However, it is not always
      possible to know what subdirectories are desired at evaluation time.

      This module adds support for evaluating "layout trees" containing btrfs
      subvolumes and generating the necessary systemd mount units (at runtime).
      systemd will invoke this module early during the boot process and after
      daemon-reload.

      The generated units will then join the job scheduler, guaranteeing
      they are activated in the correct order.
    '';

    mounts = mkOption {
      default = {};
      type = attrsOf (submodule layout-tree-opts);
    };

    configLines = mkOption {
      type = str;
      default = builtins.toJSON (attrValues cfg.mounts);
      defaultText = literalExpression "config lines";
      description = "layout-trees.yaml. By default, that generated by nixos.";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."layout-trees.yaml".text = cfg.configLines;
    systemd.generators.layout-trees =
      "${pkgs.layout-trees-generator}/bin/layout-trees-generator";
  };
}
