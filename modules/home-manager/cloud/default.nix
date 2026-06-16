{ pkgs
, ...
}:
{
  programs.awscli.enable = true;

  home.packages = with pkgs; [
    sops
    terraform
    tflint
    (google-cloud-sdk.withExtraComponents (
      with google-cloud-sdk.components;
      [
        gke-gcloud-auth-plugin
      ]
    ))
  ];
}
