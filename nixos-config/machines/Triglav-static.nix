{ config, lib, pkgs, ... }:

let
  hostname = config.networking.hostName;
  machine = builtins.getAttr hostname (import ./machines.nix {});
  secrets = import ../secrets.nix { inherit lib; };
in
{
  imports = [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix> ];

  boot = {
    cleanTmpDir = true;
    initrd = {
      kernelModules = ["dm_crypt" "cbc" "aes_x86_64" "kvm-intel" "e1000e"];
      luks = {
        devices = [
          {
            name = hostname;
            device = "/dev/disk/by-uuid/${machine.rootDeviceUuid}";
          }
        ];
      };
      network = if !secrets.secretsAvailable then {} else {
        enable = true;
        ssh.enable = true;
        ssh.authorizedKeys = secrets.adminPubKeys;
        ssh.hostRSAKey = secrets.machines."${hostname}".hostInitrdRSAKey;
        postCommands = ''
          ( ip addr add 169.254.13.13/24 dev eth0
            ip link set eth0 up
            ip addr
          ) || true
          '';
      };
      supportedFilesystems = [ "btrfs" "ext4" ];
    };
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

  swapDevices = [ ];

  fileSystems = {
    "/" = {
      fsType = "btrfs";
      mountPoint = "/";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/.__active__/rootfs" "compress=zlib"];
    };
    "/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/.snapshots";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/snapshots/rootfs" "defaults"];
    };
    "/boot" = {
      fsType = "vfat";
      mountPoint = "/boot";
      device = "/dev/disk/by-partuuid/${machine.bootPartUuid}";
    };
    "/var" = {
      fsType = "btrfs";
      mountPoint = "/var";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/.__active__/var" "compress=zlib"];
    };
    "/home" = {
      fsType = "btrfs";
      mountPoint = "/home";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/.__active__/homes" "compress=zlib" "autodefrag"];
    };
    "/Storage" = {
      fsType = "btrfs";
      mountPoint = "/Storage";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/.__active__/Storage" "compress=zlib" "autodefrag"];
    };
    "/Storage/DevelHub" = {
      fsType = "btrfs";
      mountPoint = "/Storage/DevelHub";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/.__active__/DevelHub" "compress=zlib"];
    };
    "/Storage/DevelHub/5-VMs" = {
      fsType = "btrfs";
      mountPoint = "/Storage/DevelHub/5-VMs";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/.__active__/VMs" "nodatacow"];
    };
    "/home/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/home/.snapshots";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/snapshots/homes" "defaults"];
    };
    "/Storage/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/Storage/.snapshots";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/snapshots/Storage" "defaults"];
    };
    "/Storage/DevelHub/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/Storage/DevelHub/.snapshots";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/snapshots/DevelHub" "defaults"];
    };
    "/mnt/root-btrfs" = {
      fsType = "btrfs";
      mountPoint = "/mnt/root-btrfs";
      device = "/dev/mapper/" + hostname;
      options = ["nodatacow" "noatime" "noexec"];
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  services.snapper.configs = let
    extraConfig = ''
      ALLOW_GROUPS="wheel"
      TIMELINE_CREATE="yes"
      TIMELINE_CLEANUP="yes"
      EMPTY_PRE_POST_CLEANUP="yes"
    '';
  in {
    "home" = {
      subvolume = "/home";
      inherit extraConfig;
    };
    "Storage" = {
      subvolume = "/Storage";
      inherit extraConfig;
    };
    "DevelHub" = {
      subvolume = "/Storage/DevelHub";
      inherit extraConfig;
    };
  };
}
