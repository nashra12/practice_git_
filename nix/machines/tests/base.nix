{ config, lib, pkgs, secrets, modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  options.virtualisation.enableGraphics = lib.mkEnableOption "Graphics support";
  options.virtualisation.configureNetwork = lib.mkOption {
    description = "Whether to configure VM network services";
    default = true;
    type = lib.types.bool;
  };

  config = {
    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };

    environment.etc."systemd/network/00-random-mac.link".text = ''
      [Match]
      OriginalName=*

      [Link]
      MACAddressPolicy=random
    '';

    fileSystems."/boot" = { fsType = "vfat"; device = "/dev/sda1"; };
    fileSystems."/".device = "/dev/sda2";

    networking = lib.mkIf config.virtualisation.configureNetwork {
      firewall.allowedUDPPorts = [ 5355 ];
      interfaces.eth0.useDHCP = true;
      useDHCP = false;
      useNetworkd = true;
    };

    nix.package = pkgs.nixUnstable;
    nix.trustedUsers = [ "roos" ];
    nix.extraOptions = "experimental-features = nix-command flakes";

    security.sudo.enable = true;
    security.sudo.wheelNeedsPassword = false;

    services.journald.console = "/dev/ttyS0";
    services.getty.autologinUser = "roos";
    systemd.coredump.enable = true;
    security.pam.loginLimits = [{
      domain = "*"; item = "core"; type = "-"; value = "-1";
    }];

    users.mutableUsers = false;
    users.users.roos.password = "roos";
    users.users.roos.isNormalUser = true;
    users.users.roos.extraGroups = ["wheel"];

    virtualisation.qemu.options = [
      "-device virtio-balloon-pci,id=balloon0,bus=pci.0"
      "-chardev stdio,mux=on,id=char0,signal=off"
      "-mon chardev=char0,mode=readline"
      "-serial chardev:char0"
      "-snapshot"
    ] ++ lib.optional (!config.virtualisation.enableGraphics) "-nographic";
  };
}
