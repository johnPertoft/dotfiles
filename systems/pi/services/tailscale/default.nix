{ ... }:

{
  # Remote access to the Pi (and, if you `tailscale up --advertise-routes`, the
  # rest of the LAN). The module opens its own UDP port. Run `sudo tailscale up`
  # once after the first boot.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Everything reachable over Tailscale is trusted (Grafana, SSH, etc.).
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
