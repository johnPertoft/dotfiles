{ pkgs
, ...
}:
{
  # Databases and tabular-data tooling.
  home.packages = with pkgs; [
    duckdb
    postgresql
    sqlitebrowser
    visidata
  ];
}
