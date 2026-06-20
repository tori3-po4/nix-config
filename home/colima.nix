{
  # Home Manager の Colima module に任せる。
  # - ~/.colima/default/colima.yaml を Nix 生成にする
  # - LaunchAgent から default profile をログイン時に起動する
  # - settings を持つ profile は --save-config=false で起動される
  services.colima = {
    enable = true;
    colimaHomeDir = ".colima";

    profiles.default = {
      isActive = true;
      isService = true;

      settings = {
        cpu = 2;
        disk = 100;
        memory = 2;
        arch = "aarch64";
        runtime = "docker";
        modelRunner = "docker";
        hostname = "colima";

        kubernetes = {
          enabled = false;
          version = "v1.35.0+k3s1";
          k3sArgs = [ "--disable=traefik" ];
          port = 0;
        };

        autoActivate = true;

        network = {
          address = false;
          mode = "shared";
          interface = "en0";
          preferredRoute = false;
          dns = null;
          dnsHosts = { };
          hostAddresses = false;
          gatewayAddress = "192.168.5.2";
        };

        forwardAgent = false;
        docker = { };
        vmType = "vz";
        portForwarder = "ssh";
        rosetta = false;
        binfmt = true;
        nestedVirtualization = false;
        mountType = "virtiofs";
        mountInotify = true;
        cpuType = "";
        provision = null;
        sshConfig = true;
        sshPort = 0;
        mounts = [ ];
        diskImage = "";
        rootDisk = 20;
        env = { };
      };
    };
  };
}
