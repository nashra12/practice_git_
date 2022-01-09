{ config, lib, pkgs, secrets, ... }:

let
  hostname = config.networking.hostName;
  uuids = {
    bootPart = "1f9a0153-ea97-49bc-a2a7-b679e46679ae";
    systemDevice = "2452fc3b-7c05-4024-9d08-3be509a645cd";
  };
in
{
  boot = {
    cleanTmpDir = true;
    initrd = {
      availableKernelModules = [ "xhci_pci" "nvme" "sd_mod" ];
      kernelModules = ["dm_crypt" "cbc" "kvm-intel" "e1000e"];
      luks.devices."${hostname}".device = "/dev/disk/by-uuid/${uuids.systemDevice}";
      supportedFilesystems = [ "btrfs" "ext4" ];
    };
    kernelModules = ["acpi_call"];
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call v4l2loopback ];
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
        gfxmodeEfi = "1280x1024x32,1024x768x32,auto";
      };
    };
  };

  hardware.enableRedistributableFirmware = true;

  swapDevices = [
    { device = "/mnt/root-btrfs/subvolumes/swap/swapfile1"; }
  ];

  fileSystems = {
    "/" = {
      fsType = "btrfs";
      mountPoint = "/";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/active/rootfs" "compress=zlib" "user_subvol_rm_allowed"];
    };
    "/boot" = {
      fsType = "vfat";
      mountPoint = "/boot";
      device = "/dev/disk/by-partuuid/${uuids.bootPart}";
    };
    "/var" = {
      fsType = "btrfs";
      mountPoint = "/var";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/active/var" "compress=zlib" "user_subvol_rm_allowed"];
    };
    "/nix" = {
      fsType = "btrfs";
      mountPoint = "/nix";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/active/nix" "compress=zlib" "defaults" "noatime" "autodefrag" "nodatacow"];
    };
    "/home" = {
      fsType = "btrfs";
      mountPoint = "/home";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/active/home" "compress=zlib" "autodefrag" "user_subvol_rm_allowed"];
    };
    "/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/.snapshots";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/snapshots/rootfs" "defaults" "user_subvol_rm_allowed"];
    };
    "/home/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/home/.snapshots";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/snapshots/home" "defaults" "user_subvol_rm_allowed"];
    };
    "/mnt/root-btrfs" = {
      fsType = "btrfs";
      mountPoint = "/mnt/root-btrfs";
      device = "/dev/mapper/" + hostname;
      options = ["nodatacow" "noatime" "noexec" "user_subvol_rm_allowed"];
    };
  };

  services.pipewire.media-session.config.bluez-monitor.rules = [{
    # Matches all bluetooth cards
    matches = [ { "device.name" = "~bluez_card.*"; } ];
    actions."update-props" = {
      "bluez5.reconnect-profiles" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
      # mSBC is not expected to work on all headset + adapter combinations.
      "bluez5.msbc-support" = true;
    };
  } {
    matches = [
      { "node.name" = "~bluez_input.*"; }
      { "node.name" = "~bluez_output.*"; }
    ];
    actions."node.pause-on-idle" = false;
  }];

  services.pipewire.media-session.config.alsa-monitor.rules = [{
    matches = [{
      "node.description" =
        "Cannon Point-LP High Definition Audio Controller Speaker + Headphones";
    }];
    actions."update-props"."node.description" = "Laptop DSP";
    actions."update-props"."node.nick" = "Laptop audio";
    # Workaround odd bug on the session-manager where output will start in bad state.
    actions."update-props"."api.acp.autoport" = true;
  } {
    matches = [{
      "node.description" =
        "Cannon Point-LP High Definition Audio Controller Digital Microphone";
    }];
    actions."update-props"."node.description" = "Laptop Mic";
    actions."update-props"."node.nick" = "Laptop mic";
  } {
    matches = [{
      "node.description" = "~Cannon Point-LP High Definition Audio.*";
    }];
    actions."update-props"."node.pause-on-idle" = true;
  }];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  security.tpm2.enable = true;
  services.btrfs.autoScrub.enable = true;
  services.fwupd.enable = true;

  sops.secrets."ssh-client/backups-key" = {};

  roos.btrbk.enable = true;
  roos.btrbk.config = {
    snapshot_preserve = "10h 7d 4w 6m";
    snapshot_preserve_min = "1h";
    target_preserve = "7d 4w 6m";
    target_preserve_min = "no";
    backend = "btrfs-progs-sudo";
    ssh_identity = "/run/secrets/ssh-client/backups-key";
    ssh_user = config.roos.backups.remoteUser;

    timestamp_format = "long";

    volumes."/mnt/root-btrfs/subvolumes" = {
      group = "system";
      subvolumes = [ "active/rootfs" "active/home" ];
      snapshot_dir = "snapshots";
    };

    volumes."/home/roosemberth" = {
      group = "user-roosemberth";
      targets = config.roos.backups.btrbkTargets;
      subvolumes.".".snapshot_name = "homedir";
      subvolumes.".local/var" = {};
      subvolumes."nocow" = {
        snapshot_preserve = "1d";
        snapshot_preserve_min = "latest";
        target_preserve = "1d";
        target_preserve_min = "latest";
      };
      snapshot_dir = ".snapshots";
    };

    volumes."/home/roosemberth/ws" = {
      group = "user-roosemberth";
      targets = config.roos.backups.btrbkTargets;
      subvolumes = [ "." "2-Platforms" ];
      snapshot_dir = ".snapshots";
    };
  };
}
