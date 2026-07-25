{ ... }:

{
  # Remote access to the box over the tailnet. The module opens its own UDP
  # port. Run `sudo tailscale up` once after the first boot.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Everything reachable over Tailscale is trusted (Jellyfin admin, SSH,
  # Transmission RPC, node metrics, etc.).
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
