{ lib
, buildNpmPackage
, fetchurl
, jq
, nodejs_22
, ...
}:
# copilot-api (caozhiyuan fork): local gateway that exposes a GitHub Copilot
# subscription as Anthropic Messages / OpenAI Chat / OpenAI Responses APIs.
# Used by `claude-copilot` (modules/home-manager/llm/claude-copilot.nix).
# Not in nixpkgs or llm-agents.nix, hence packaged here.
#
# Built from the published npm tarball, which ships a prebuilt dist/ but only
# a bun.lock. package-lock.json is vendored next to this file, generated from
# the tarball's package.json with devDependencies and scripts stripped (the
# same stripping postPatch does below, so the two always agree).
#
# To update:
#   1. Bump `version`, set `hash` to lib.fakeHash, build, paste the real hash.
#   2. Regenerate the lock:
#        tmp=$(mktemp -d)
#        curl -sL https://registry.npmjs.org/@jeffreycao/copilot-api/-/copilot-api-<version>.tgz \
#          | tar xz -C "$tmp" --strip-components=1
#        jq 'del(.devDependencies, .scripts)' "$tmp/package.json" > "$tmp/p" \
#          && mv "$tmp/p" "$tmp/package.json"
#        (cd "$tmp" && nix shell nixpkgs#nodejs_22 -c \
#          npm install --package-lock-only --ignore-scripts)
#        cp "$tmp/package-lock.json" packages/copilot-api/
#   3. Set `npmDepsHash` to lib.fakeHash, build, paste the real hash.
buildNpmPackage rec {
  pname = "copilot-api";
  version = "2.6.23";

  src = fetchurl {
    url = "https://registry.npmjs.org/@jeffreycao/copilot-api/-/copilot-api-${version}.tgz";
    hash = "sha256-rR8hRCz+W3jTIYrd3kFaWx0g2Li8vMmbfQ+4kpkcHCg=";
  };
  sourceRoot = "package";

  # fetchNpmDeps reuses postPatch, so the dependency fetch sees the same
  # stripped package.json and vendored lock as the build.
  postPatch = ''
    ${lib.getExe jq} 'del(.devDependencies, .scripts)' package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-k267OeTPNpJOsFtZkf3QBQdWuKzWS7xCI5dm+pvFrR0=";

  nodejs = nodejs_22;

  # dist/ is prebuilt in the npm tarball.
  dontNpmBuild = true;

  # Upstream's own `start` script sets both. NODE_USE_SYSTEM_CA makes Node
  # trust the macOS keychain, needed behind TLS-inspecting corporate proxies.
  makeWrapperArgs = [
    "--set-default"
    "NODE_USE_SYSTEM_CA"
    "1"
    "--set-default"
    "NODE_ENV"
    "production"
  ];

  meta = {
    description = "GitHub Copilot gateway with OpenAI and Anthropic API compatibility";
    homepage = "https://github.com/caozhiyuan/copilot-api";
    license = lib.licenses.mit;
    mainProgram = "copilot-api";
  };
}
