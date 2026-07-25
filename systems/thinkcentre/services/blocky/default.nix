{ ... }:

{
  # Network-wide DNS ad/tracker blocking. At cutover this box takes the static
  # LAN IP 192.168.0.2 that clients/router point DNS at (deferred, see README);
  # until then it just serves on its DHCP address. Metrics are exported on the
  # HTTP port below (scraped by the monitoring host once ./monitoring is wired).
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53;
      ports.http = 4000;
      prometheus.enable = true;
      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
      upstreams.groups.default = [ "https://one.one.one.one/dns-query" ];
      bootstrapDns = {
        upstream = "https://one.one.one.one/dns-query";
        ips = [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };
      blocking = {
        blackLists.ads = [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
          "https://big.oisd.nl/domainswild"
        ];
        clientGroupsBlock.default = [ "ads" ];
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
}
