# Grafana dashboards

Drop exported dashboard JSON files here. They're auto-provisioned by the file
provider wired up in `../default.nix` — no config change needed, just add the
`.json` and rebuild. Grafana ignores non-JSON files (like this README).

Export from Grafana via **Dashboard → Share → Export → Save to file**, or grab a
community dashboard's JSON (e.g. node-exporter #1860). Set a stable `uid` in the
JSON so links survive re-imports.
