{ pkgs, ... }:

let
  # A single static page listing the Pi's user-facing services. Kept as one
  # self-contained HTML file (no build step, no external resources) so it works
  # even when the Pi has no internet.
  #
  # Links are built client-side from window.location.hostname rather than
  # hardcoded, because the page is reachable both ways: over the LAN as
  # `pi.local` and over Tailscale as `pi` (MagicDNS). Deriving each href from
  # whatever host you loaded the page from keeps every link live on either
  # network. Transmission's :9091 is Tailscale-only (not on the LAN firewall),
  # so its link is expected to be dead on the LAN — hence the label.
  homepage = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>pi</title>
      <style>
        :root { color-scheme: dark; }
        body {
          margin: 0;
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          font: 16px/1.5 system-ui, sans-serif;
          background: #14161a;
          color: #e6e6e6;
        }
        main { width: min(90vw, 32rem); }
        h1 { margin: 0 0 1.5rem; font-size: 1.4rem; color: #8ab4f8; }
        ul { list-style: none; margin: 0; padding: 0; }
        li { margin: 0.5rem 0; }
        a {
          display: flex;
          justify-content: space-between;
          align-items: baseline;
          padding: 0.9rem 1.1rem;
          border-radius: 0.6rem;
          background: #1e2126;
          color: inherit;
          text-decoration: none;
        }
        a:hover { background: #262a31; }
        .note { font-size: 0.8rem; color: #8b909a; }
      </style>
    </head>
    <body>
      <main>
        <h1>pi</h1>
        <ul id="services"></ul>
      </main>
      <script>
        var host = window.location.hostname;
        var services = [
          { name: "Grafana", port: 3000, note: "metrics & logs" },
          { name: "Jellyfin", port: 8096, note: "media" },
          { name: "Home Assistant", port: 8123, note: "home automation" },
          { name: "Mealie", port: 9000, note: "recipes & meal planning" },
          { name: "Transmission", port: 9091, note: "downloads · Tailscale only" }
        ];
        var ul = document.getElementById("services");
        services.forEach(function (s) {
          var a = document.createElement("a");
          a.href = "http://" + host + ":" + s.port;
          var name = document.createElement("span");
          name.textContent = s.name;
          var note = document.createElement("span");
          note.className = "note";
          note.textContent = s.note;
          a.appendChild(name);
          a.appendChild(note);
          var li = document.createElement("li");
          li.appendChild(a);
          ul.appendChild(li);
        });
      </script>
    </body>
    </html>
  '';
in
{
  # Landing page for the box: hit http://pi.local (LAN) or http://pi (tailnet)
  # and get a list of links to everything else the Pi hosts. Static file served
  # by nginx; forward-compatible with reverse-proxying the *arr stack later.
  services.nginx = {
    enable = true;
    virtualHosts."pi" = {
      default = true;
      root = "${homepage}";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
