# Grouping namespace for editor modules. Each editor stays individually
# importable as `self.homeModules.editors.<name>` so homes opt in per
# editor (e.g. cursor/zed are defined here but only enabled where wanted).
{
  vscode = import ./vscode;
  vim = import ./vim;
  cursor = import ./cursor;
  zed = import ./zed;
}
