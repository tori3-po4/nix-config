{
  pkgs,
  app ? pkgs.hello,
  name ? "nix-hello",
  tag ? "latest",
  command ? [ "/bin/hello" ],
}:
pkgs.dockerTools.buildImage {
  inherit name tag;

  # created は指定しない。dockerTools の既定値 (Unix epoch + 1s) を使い、
  # 同じ入力から同じ image が生成されるようにする。
  copyToRoot = pkgs.buildEnv {
    name = "${name}-root";
    paths = [
      app
      pkgs.cacert
      pkgs.dumb-init
    ];
    pathsToLink = [
      "/bin"
      "/etc"
    ];
  };

  config = {
    Env = [ "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" ];
    Entrypoint = [
      "/bin/dumb-init"
      "--"
    ];
    Cmd = command;
  };

  compressor = "zstd";
}
