{ pkgs
, self
, ...
}:
{
  home.packages = with pkgs; [
    buildah
    buildkit
    dive
    docker-client
    docker-slim
    k9s
    kind
    kubectl
    kubectx
    kubernetes-helm
    minikube
    podman
    skaffold
    self.packages.${stdenv.hostPlatform.system}.fzf-k8s
  ];
}
