# Linux の GPU・CUDA

[README に戻る](../README.md)

[Linux の初回セットアップ](setup.md#linux)と併せて参照する。GPU 連携を有効にする場合は NVIDIA の版・ハッシュをホストごとに合わせる。CUDA の導入は後日対応する。

- [管理方針](#管理方針)
- [Nix 版 GUI の GPU 連携](#nix-版-gui-の-gpu-連携)
- [Mesa](#mesa-を使う場合) / [NVIDIA](#nvidia-専用ドライバーを使う場合)
- [確認と切り分け](#確認と切り分け)

## 管理方針

Linux の汎用パッケージと VirtualBox は `scripts/install-linux-software.sh` で導入し、Home Manager は設定・Emacs・シェルモジュール・ユーザ単位の Flatpak を管理する。

**CUDA 本体と PATH・環境変数は、後日作成する専用スクリプトで導入する。** 現時点では CUDA の導入処理を含めず、`linux/default.nix` でも CUDA の場所やコンパイラを指定しない。

以前の `/usr/local/cuda-13.4/bin` の PATH 追加、`CUDA_PATH`・`CUDACXX`・`CUDAHOSTCXX`・`NVCC_CCBIN`、Nix コンパイラ向けの `NIX_LDFLAGS_…` は削除した。設定反映前から開いているシェルやデスクトップセッションには古い環境変数が残ることがあるため、反映後はログアウト・ログインする。

今後 CUDA を導入するときは、OS 側のドライバー・SDK・対応コンパイラを選び、その配置に合わせて環境変数を設定する。導入済みの CUDA やドライバーを Home Manager が削除することはない。

参考: [CUDA の導入・ホストコンパイラ要件](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)。

## Nix 版 GUI の GPU 連携

Fedora のカーネル側 GPU ドライバーは OS 側で管理する。Nix 版 GUI が使う
描画ライブラリは Home Manager の GPU 連携で用意する。この設定は Fedora の
ドライバーをインストール・置換するものではない。

`targets.genericLinux` は汎用パッケージの導入方法に関係なく有効にする。現在の設定は NVIDIA `615.71.09` とそのハッシュを指定しているので、適用前にホストに合わせる。

Emacs の PGTK 版は Nix で導入するため、GPU 連携も Home Manager で管理する。汎用パッケージ全体を Nix 管理へ戻す必要はない。Flatpak アプリの描画ライブラリは Flatpak 側で管理される。VirtualBox は OS のパッケージを使い、ホスト用カーネルモジュールも[セットアップ用スクリプト](setup.md#3-virtualbox)で導入する。

### Mesa を使う場合

`linux/default.nix` の既存の `targets.genericLinux` を次のように変更する。

```nix
targets.genericLinux = {
  enable = true;
  gpu = {
    enable = true;
    nvidia.enable = false;
  };
};
```

この Home Manager では、`genericLinux.enable = true` かつ nixGL 未設定なら
`gpu.enable` も既定で有効になる。上記では意図を明示している。
GPU 連携と既存の nixGL 設定は併用しない。

```bash
home-manager switch --flake ~/nix-config#default --impure
sudo "$HOME/.nix-profile/bin/non-nixos-gpu-setup"
```

セットアップは `/etc/tmpfiles.d/non-nixos-gpu.conf` を登録し、
`/run/opengl-driver` を Nix の GPU ライブラリ群へリンクする。
再起動時にもリンクが復元され、対象の Nix store パスは GC から保護される。
Fedora の `/usr/lib64` 全体を `LD_LIBRARY_PATH` に追加する手順ではない。

### NVIDIA 専用ドライバーを使う場合

まず OS 側で NVIDIA ドライバーを導入して再起動し、`nvidia-smi` が正常に
動くことを確認する。既存の NVIDIA 設定を、ホストに対応する次の値へ更新する。
プレースホルダーは実際の値へ置き換えること。

```nix
targets.genericLinux = {
  enable = true;
  gpu = {
    enable = true;
    nvidia = {
      enable = true;
      version = "<OS側で動作中のドライバーバージョン>";
      sha256 = "<対応する配布ファイルのsha256-SRIハッシュ>";
    };
  };
};
```

`version` は **OS 側で動作中のドライバーと完全一致**させる。
`nvidia-smi` の「CUDA Version」ではなく「Driver Version」を使う。
ハッシュは同じバージョンの NVIDIA 配布ファイルから取得する。
現在の x86_64 ホストでの例（`.run` ファイルは実行しない）：

```bash
nvidia-smi --query-gpu=driver_version --format=csv,noheader
# 上で確認した値を入力
read -r -p 'NVIDIA driver version: ' nvidia_version
nix store prefetch-file --json \
  "https://download.nvidia.com/XFree86/Linux-x86_64/${nvidia_version}/NVIDIA-Linux-x86_64-${nvidia_version}.run"
```

出力の `hash` を `sha256` に設定する。aarch64 では URL 内の
`Linux-x86_64` を両方とも `Linux-aarch64` に変更する。
その後、Mesa の場合と同じ `home-manager switch` と
`sudo "$HOME/.nix-profile/bin/non-nixos-gpu-setup"` を実行する。
OS 側の NVIDIA ドライバーを更新したら、Nix 側のバージョン・ハッシュも更新し、
再適用・再セットアップする。通常の Nix 更新でも GPU ライブラリが変わり、
Home Manager が再セットアップを案内した場合は、そのコマンドを再実行する。

### 確認と切り分け

```bash
readlink -f /run/opengl-driver
ls /run/opengl-driver/share/glvnd/egl_vendor.d/
fc-match "HackGen Console NF"
```

フォント認識と GPU 描画の成功は別々に確認する。

手順と NVIDIA のバージョン一致条件は [Home Manager 公式マニュアル](https://nix-community.github.io/home-manager/usage/gpu-non-nixos.html) を参照する。実装を確認する場合は、`flake.lock` の `home-manager.locked.rev` に対応するソースを使う。
