{ config, lib, pkgs, dotfileUtils, ... }: with lib; let
  waybar' = with pkgs; let
    cfgFile = dotfileUtils.fetchDotfile "etc/waybar/config";
    styleFile = dotfileUtils.fetchDotfile "etc/waybar/style.css";
  in stdenv.mkDerivation {
    name = "waybar-hyprland-with-config";
    version = waybar-hyprland.version;
    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      makeWrapper ${waybar-hyprland}/bin/waybar "$out/bin/waybar" \
        --prefix PATH : "${lib.makeBinPath [ hyprland pavucontrol procps ]}" \
        --add-flags "--config ${cfgFile} --style ${styleFile}"
    '';
  };

in {
  options.sessions.hyprland.enable = mkEnableOption "Hyprland wayland session";

  config = mkIf config.sessions.hyprland.enable {
    session.wayland.enable = true;
    systemd.user.services.waybar-hyprland = {
      Unit.Description = "A wayland taskbar for hyprland";
      Unit.PartOf = [ "hyprland-session.target" ];
      Install.WantedBy = [ "hyprland-session.target" ];
      Service = {
        ExecStart = "${waybar'}/bin/waybar";
        Restart = "always";
        RestartSec = "3";
      };
    };

    wayland.windowManager.hyprland = let
      terminal = "${pkgs.foot}/bin/foot";
    in {
      enable = true;
      extraConfig = ''
        bind=SUPER,RETURN,exec,${terminal}
      '';
    };
  };
}
