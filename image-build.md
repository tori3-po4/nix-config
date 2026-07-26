# Nix による Docker / VM image build

このリポジトリは Docker load 用の Linux image と、UEFI で起動する NixOS
qcow2 image を `packages.<architecture>-linux` として公開する。

macOS の `pkgs` で Docker image を作ると Darwin 用 Mach-O binary が入り、
Linux container では実行できない。そこで nix-darwin の `nix.linux-builder` を
常駐させ、Linux derivation を SSH 経由で builder VM に送り、生成物を macOS
側の Nix store に戻す。

## 初回セットアップ

Apple Silicon では最初に native aarch64-linux builder を起動し、その builder
を使って x86_64-linux の binfmt/QEMU 対応版をビルドする。初回のみ二段階で
反映する。

```bash
cd ~/nix-config
nh darwin switch "path:$PWD" --hostname bootstrap --impure
nh darwin switch "path:$PWD" --impure
```

`bootstrap` は Mac と同じ architecture の Linux VM だけを有効にする。通常構成は
その VM 内で x86_64-linux をエミュレーションし、両 architecture を build machine
として公開する。

設定を確認する場合:

```bash
nix config show | grep '^builders ='
nix build nixpkgs#legacyPackages.aarch64-linux.hello --no-link -L
```

Intel Mac では確認コマンドの `aarch64-linux` を `x86_64-linux` に置き換える。

## GTX 1060対応GUIインストーラー

Plasma 6とCalamaresを含むx86_64 ISOをビルドする。

```bash
cd ~/nix-config
nix build --impure \
  'path:.#packages.x86_64-linux.iso-gui-gtx1060-server' \
  -L -o result-iso
ls -lh result-iso/iso/*.iso
```

GTX 1060では起動メニューの `NVIDIA GTX 1060 (legacy 580)` を選ぶ。通常項目は
Intel、AMD、Nouveau用のフォールバックとして残している。

このカスタムCalamaresは、インストール先へ
`/etc/nixos/gtx1060-server.nix` を配置し、生成する `configuration.nix` から
自動的にimportする。次の設定がインストール後も有効になる。

- GTX 1060向けNVIDIA proprietary legacy 580 driver
- DockerとDocker Compose
- NVIDIA Container Toolkit（CDI）
- Tailscale
- WireGuard tools

初回起動後の確認:

```bash
nvidia-smi
sudo tailscale up
sudo docker run --rm \
  --device=nvidia.com/gpu=all \
  ubuntu:24.04 nvidia-smi -L
```

WireGuardは接続先と秘密鍵が環境固有なので自動接続しない。秘密鍵をNix storeへ
入れないよう、次のようにrootだけが読める場所へ生成する。

```bash
sudo install -d -m 0700 /var/lib/wireguard
sudo sh -c 'umask 077; wg genkey > /var/lib/wireguard/wg0.key'
sudo nano /etc/nixos/gtx1060-server.nix
sudo nixos-rebuild switch
```

`gtx1060-server.nix` 内の `networking.wg-quick.interfaces.wg0` 例を、実際の
address、peer public key、endpointに合わせて有効化する。Dockerの代わりに
Podmanを使う場合の切り替え例も同じファイルに記載している。

## Docker image

Apple Silicon Mac では次のようにビルドして Docker Desktop にロードする。

```bash
nix build .#packages.aarch64-linux.docker-image \
  --impure -L -o docker-image.tar.zst
docker image load -i docker-image.tar.zst
docker container run --rm nix-hello:latest
```

Intel Mac では `aarch64-linux` を `x86_64-linux` に置き換える。サンプル image は
`hello` を `dumb-init` 経由で実行する。image 名、tag、application、command は
`images/docker.nix` の引数なので、flake の `callPackage` で上書きできる。

```nix
docker-image = pkgs.callPackage ./images/docker.nix {
  app = myApp;
  name = "my-app";
  tag = "latest";
  command = [ "/bin/my-app" ];
};
```

`created = "now"` は指定せず、dockerTools の固定時刻を利用する。同じ入力から
同じ image を生成できるようにするためである。

## qcow2 VM image

Apple Silicon Mac でのビルド:

```bash
nix build .#packages.aarch64-linux.qcow2 \
  --impure -L -o vm-image
ls -lh vm-image/*.qcow2
```

Intel Mac では `x86_64-linux` を指定する。出力はそれぞれ
`nix-vm-aarch64-linux.qcow2` / `nix-vm-x86_64-linux.qcow2` となる。
変換前の GPT raw image が必要なら、同じコマンドの `qcow2` を `vm-raw` に
置き換える。他の VM disk 形式も `vm-raw` を入力に `qemu-img` で追加できる。

VM の NixOS 設定は `images/vm.nix` にある。サンプルは DHCP、`hello`、コンソール
自動ログイン用の `nixos` ユーザを含むが、SSH とパスワードログインは有効にして
いない。実運用ではこの module に service、package、user、公開鍵などを追加する。

qcow2 は NixOS の `systemd-repart` で GPT の raw disk、ESP、root filesystem、UKI
を直接生成し、`qemu-img` で変換する。従来の `make-disk-image.nix` のように build
中に KVM VM をもう一段起動しないため、nested virtualization 非対応の Mac でも
Linux builder 上で生成できる。

## 構成

- `darwin/linux-builder.nix`: builder VM、SSH、Nix build machine の宣言
- `images/docker.nix`: Docker image の内容と runtime config
- `images/vm.nix`: NixOS と systemd-repart の disk layout
- `images/iso.nix`: GTX 1060対応GUIインストーラー
- `nixos/profiles/gtx1060-server.nix`: インストール先のサーバー設定
- `flake.nix`: Linux package 出力と raw → qcow2 変換

どちらも macOS からは `.#docker-image` のような current-system shorthand を使わず、
必ず `.#packages.aarch64-linux...` または `.#packages.x86_64-linux...` を指定する。
これが Darwin binary の混入を防ぐポイントになる。

## 参考資料

- [Darwin ホストで Nix で Docker image をビルド](https://nymphium.github.io/2026/01/11/nix-image-build.html)
- [nix-darwin: `nix.linux-builder` options](https://nix-darwin.github.io/nix-darwin/manual/)
- [NixOS Manual: Building Images via systemd-repart](https://nixos.org/manual/nixos/unstable/#sec-image-repart)
