{ lib, dockerTools, buildEnv, pkgsLinux, deterministic-uname, cacert, fix-corefoundation-cross-hook }:

let
  inherit (pkgsLinux) stdenv bashInteractive coreutils gnutar gzip tini xz iana-etc;

  isCross = stdenv.buildPlatform != pkgsLinux.stdenv.hostPlatform;

  host-deterministic-uname = deterministic-uname.override (lib.optionalAttrs isCross {
    stdenv = stdenv // { buildPlatform = pkgsLinux.stdenv.hostPlatform; };
  });

  aws-sdk-cpp = (pkgsLinux.aws-sdk-cpp.override (lib.optionalAttrs isCross {
    apis = [ "s3" "transfer" ];
    customMemoryManagement = false;
  })).overrideAttrs (prev: (lib.optionalAttrs isCross {
    nativeBuildInputs = [ fix-corefoundation-cross-hook ] ++ prev.nativeBuildInputs;
    requiredSystemFeatures = [ ];
  }));

  busybox-sandbox-shell = pkgsLinux.busybox-sandbox-shell.override (lib.optionalAttrs isCross {
    busybox = pkgsLinux.busybox;
  });

  openssh = pkgsLinux.openssh.override (lib.optionalAttrs isCross {
    withFIDO = false;
  });

  gitMinimal = pkgsLinux.gitMinimal.overrideAttrs (prev: (lib.optionalAttrs isCross {
    nativeBuildInputs = [ host-deterministic-uname ] ++ prev.nativeBuildInputs;
    doInstallCheck = false;
  }));

  nix = pkgsLinux.nix.override (lib.optionalAttrs isCross {
    aws-sdk-cpp = aws-sdk-cpp;
    busybox-sandbox-shell = busybox-sandbox-shell;
  });
in
dockerTools.buildImageWithNixDb {
  inherit (nix) name;

  copyToRoot = buildEnv {
    name = "root";
    paths = [
      ./src/root
      bashInteractive
      coreutils
      gitMinimal
      gnutar
      gzip
      iana-etc
      cacert
      nix
      openssh
      tini
      xz
    ];
    ignoreCollisions = true;
  };

  extraCommands = ''
    mkdir usr
    ln -s ../bin usr/bin

    mkdir -m 1777 tmp
    mkdir -p var/empty
    mkdir -p root
  '';

  config = {
    Cmd = [ "tini" "--" "/bin/sshd" "-D" ];
    Env = [
      "NIX_BUILD_SHELL=/bin/bash"
      "PAGER=cat"
      "PATH=/usr/bin:/bin"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "USER=root"
    ];
  };
}
