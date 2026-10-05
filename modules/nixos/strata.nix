{ config, lib, pkgs, ... }:
let
  version = "0.1.39";
  tag = "strata:${version}";

  # Upstream publishes no Linux image, so build theirs from a pinned source.
  # Bump version + hash together (`nix flake prefetch github:Niko1221/Strata/v<version>`).
  src = pkgs.fetchFromGitHub {
    owner = "Niko1221";
    repo = "Strata";
    rev = "v${version}";
    hash = "sha256-9jqmV+AbGKiOqW1DvKjqBLVXmJCI9o6WI85QoHj5vBI=";
  };

  docker = "${config.virtualisation.docker.package}/bin/docker";
in
{
  # Strata (https://github.com/Niko1221/Strata): Qwen3.8-Flash-Next on the
  # RTX 5070, OpenAI/Anthropic-compatible API on http://127.0.0.1:8080.
  #
  # On demand only, it pins ~35 GB of RAM and most of the VRAM while running:
  #   sudo systemctl start docker-strata    # first start builds the image, then downloads the model
  #   sudo systemctl stop docker-strata
  #   journalctl -fu strata-image -fu docker-strata
  # Old images aren't pruned on a version bump: `docker image rm strata:<old>`.

  # Builds the image when it's missing (first start, version bump, prune).
  # Compiling the engine takes a while, hence no timeout.
  systemd.services.strata-image = {
    description = "Build the Strata ${version} container image";
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "infinity";
    };
    script = ''
      ${docker} image inspect ${tag} >/dev/null 2>&1 && exit 0
      ${docker} build --tag ${tag} --build-arg CUDA_ARCHITECTURES=120 ${src}
    '';
  };

  systemd.services.docker-strata = {
    requires = [ "strata-image.service" ];
    after = [ "strata-image.service" ];
    # A crash while loading would otherwise re-pin ~35 GB in a tight loop.
    serviceConfig.Restart = lib.mkForce "no";
  };

  # The image lives in Docker's store (podman is the default for stateVersion >= 22.05).
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.strata = {
    image = tag;
    pull = "never";
    autoStart = false;
    # The entrypoint listens on 0.0.0.0 without an API key, and Docker-published
    # ports bypass the NixOS firewall, so only publish on loopback.
    ports = [ "127.0.0.1:8080:8080" ];
    volumes = [ "/var/lib/strata:/data" ];
    devices = [ "nvidia.com/gpu=all" ];
    extraOptions = [ "--ulimit=memlock=-1" ];
    environment = {
      FAMILY = "coder";
      MODEL = "IQ1_M";
    };
  };

  systemd.tmpfiles.rules = [ "d /var/lib/strata 0755 root root -" ];
}
