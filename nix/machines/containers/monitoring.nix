{ config, pkgs, lib, secrets, containerHostConfig, ... }:
{
  containers.monitoring = {
    autoStart = true;
    bindMounts.prometheus.hostPath = "/mnt/cabinet/minerva-data/prometheus2";
    bindMounts.prometheus.mountPoint = "/var/lib/prometheus2";
    bindMounts.prometheus.isReadOnly = false;
    config = {
      networking.firewall.allowedTCPPorts = [ 9090 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = containerHostConfig.nameservers;
      networking.search = with secrets.network.zksDNS; [ search ];
      networking.useHostResolvConf = false;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";

      services.prometheus = {
        enable = true;
        webExternalUrl = "https://monitoring.orbstheorem.ch/";
        ruleFiles = [
          ./prometheus/synapse-v2.rules  # Rules for matrix-synapse
        ];
        scrapeConfigs = [{
          job_name = "synapse";
          metrics_path = "/_synapse/metrics";
          # For some reason, the "official" synapse Grafana chart requires 15s?
          scrape_interval = "15s";
          static_configs = [{ targets = [ "minerva.int:9092" ];}];
        } {
          job_name = "node";
          static_configs = [{ targets = [
            "localhost:9100"
            "minerva.int:9100"
          ];}];
        } {
          job_name = "postgres";
          static_configs = [{ targets = [ "minerva.int:9187" ];}];
        }];
      };
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.6/24";
    hostBridge = "containers";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 9090; protocol = "tcp"; }
    ];
  };

  roos.container-host.firewall.monitoring = {
    in-rules = [
      "-p udp -m udp --dport 53 -j ACCEPT"
      "-j ACCEPT"  # Monitoring can access the host.
    ];
    ipv4.fwd-rules = [ "-j ACCEPT" ];
  };
}
