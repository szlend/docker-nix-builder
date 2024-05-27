{ lib, stdenv, resholve, shellcheck-minimal, makeWrapper, bash, coreutils, getconf, docker-nix-builder-image }:

resholve.mkDerivation rec {
  pname = "docker-nix-builder";
  version = "0.1";
  src = ./src;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    ${lib.getExe shellcheck-minimal} $src/docker-nix-builder.sh
    ${stdenv.shellDryRun} $src/docker-nix-builder.sh
    runHook postCheck
  '';

  installPhase = ''
    mkdir -p $out/{bin,share/docker-nix-builder}
    cp -p $src/docker-nix-builder.sh $out/share/docker-nix-builder/docker-nix-builder.sh

    makeWrapper $out/share/docker-nix-builder/docker-nix-builder.sh $out/bin/docker-nix-builder \
      --set DOCKER_NIX_BUILDER_IMAGE ${docker-nix-builder-image}
  '';

  solutions = {
    default = {
      scripts = [ "share/docker-nix-builder/docker-nix-builder.sh" ];
      interpreter = "${bash}/bin/bash";
      inputs = [ coreutils getconf ];
      fake = {
        external = [ "docker" "ssh" "ssh-keygen" ];
      };
    };
  };
}
