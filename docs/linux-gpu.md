# Linux の GPU・CUDA

[README に戻る](../README.md)

[Linux の初回セットアップ](setup.md#linux)と併せて参照する。NVIDIA の版・ハッシュ、CUDA の配置はホストごとに合わせる。

- [管理方針](#管理方針)
- [Nix 版 GUI の GPU 連携](#nix-版-gui-の-gpu-連携)
- [Mesa](#mesa-を使う場合) / [NVIDIA](#nvidia-専用ドライバーを使う場合)
- [確認と切り分け](#確認と切り分け)

## 管理方針

Linux では **GPU / CUDA 一式を OS 側の SDK として dnf で管理し、汎用の開発ツールと個人の設定を Nix / Home Manager で管理する**。
普段使う CUDA 環境はホストごとに用意し、Home Manager のグローバル環境には汎用開発ツールを配置する方針とする。

| 対象 | 管理場所 | 理由 |
|---|---|---|
| NVIDIA カーネルドライバー | dnf | OS のカーネルと連携するため |
| ドライバーの `libcuda.so.1` | OS 側のドライバーを基準に管理 | カーネル側ドライバーと整合させるため |
| Docker / Podman・NVIDIA Container Toolkit | dnf | ホストのサービスやデバイスと連携するため |
| CUDA Toolkit（NVCC・CUDA ヘッダ） | dnf（対応する NVIDIA リポジトリ等） | ホスト共通の CUDA SDK として用意するため |
| CUDA ランタイムの `libcudart` | dnf | OS 側の CUDA Toolkit と揃えるため |
| cuBLAS・cuDNN 等の必要な CUDA 関連ライブラリ | dnf | CUDA SDK と同じ管理系統で依存関係を揃えるため |
| GCC / G++・Clang / clangd・CMake / Ninja 等の汎用開発ツール | Nix | 必要な版とツール構成を宣言し、別マシンへ持ち運ぶため |
| エディタ・LSP 設定・ドットファイル | Nix / Home Manager | 個人の開発環境を再現するため。SSH 接続設定はローカル管理、Neovim はデフォルト設定 |

**設計の意図**: 持ち運びたい個人の開発環境と、各ホストで用意する GPU / CUDA 基盤の境界を明確にする。
CUDA Toolkit・ヘッダ・ランタイム・関連ライブラリを dnf 側へまとめ、Nix で分かれている CUDA の構成要素から SDK の配置を組み立てる手間を抑える。
汎用開発ツールは既存の Nix 管理を活かし、CUDA のためだけにすべてを OS 側へ入れ直さない。
これは「ランタイムはすべて dnf」という分類ではなく、標準の CUDA SDK を一式で OS 側へ置く方針である。Nix 製ツール自身の実行時依存ライブラリは Nix に任せる。

**管理境界をまたぐ設定と運用**:

- **コンパイラの選択**: NVCC が対応する GCC / G++ の版を Nix 側で選ぶ。CUDA のドライバー要件と、NVCC のホストコンパイラ要件は別に確認する。CMake では `CMAKE_CUDA_COMPILER` と `CMAKE_CUDA_HOST_COMPILER` を初回構成時に明示し、通常の C++ 用の `CMAKE_CXX_COMPILER` も同じ対応版 G++ に揃える。Nix のラッパーやライブラリ検索先も含め、実ビルドで確認する。
- **clangd の連携**: Nix 版 clangd に `compile_commands.json` を渡し、必要に応じて `.clangd` で OS 側 CUDA の場所（`--cuda-path`）、標準ヘッダの検索先、NVCC 固有の引数を調整する。CUDA ファイルでの LSP 起動もエディタ側で設定する。dnf で SDK を導入しても、この連携がすべて自動設定されるわけではない。
- **プロジェクト固有の条件**: ソース一覧、マクロ、言語規格、GPU アーキテクチャは CMake 等で管理し、コンパイル情報を生成する。手元の RTX 2060 SUPER は Compute Capability 7.5 のため、対象にする場合の CMake 指定は `CMAKE_CUDA_ARCHITECTURES=75`、clangd 側は `--cuda-gpu-arch=sm_75` とする。
- **移行と更新**: `flake.lock` が固定するのは Nix 側の環境であり、dnf 側の CUDA までは固定しない。各ホストで導入時に使用したリポジトリ・パッケージと、動作確認したドライバー / CUDA / GCC / clangd の版を記録する。更新時は CMake のコンパイル情報を再生成し、ビルド・clangd の解析・GPU 実行を個別に確認する。
- **Nix パッケージの依存関係**: Nix 製の CUDA 対応アプリが dnf の CUDA ライブラリを自動利用するわけではない。そのパッケージが宣言する Nix 側の CUDA 依存は許容する。この方針は、自分で開発・ビルドする際の標準 CUDA 環境を対象とする。
- **別バージョンが必要な場合**: CUDA の版までプロジェクト単位で再現する必要が出た場合は、そのプロジェクトに専用の Nix `devShell` またはコンテナ環境を用意する。

以下の [Nix 版 GUI の GPU 連携](#nix-版-gui-の-gpu-連携)も併用する。Home Manager が Nix アプリ向けにドライバーライブラリを用意する場合も、NVIDIA の版は OS 側に合わせる。これは CUDA Toolkit の管理を Nix へ移すものではない。

現在の `linux/default.nix` には以下を宣言している。別ホストでは適用前に実環境へ合わせる。

- `targets.genericLinux.gpu.nvidia`: 有効、ドライバーバージョン `615.71.09` と対応ハッシュを固定
- `home.sessionPath`: `/usr/local/cuda-13.4/bin` を追加
- `CUDA_PATH`: `/usr/local/cuda-13.4`
- `CUDACXX`: `/usr/local/cuda-13.4/bin/nvcc`
- `CUDAHOSTCXX` / `NVCC_CCBIN`: Nix の `pkgs.gcc` が提供する `g++`
- `NIX_LDFLAGS_${pkgs.stdenv.cc.suffixSalt}`: NVIDIA 連携が有効な場合に `-rpath /run/opengl-driver/lib`

これらは既存 SDK の参照先を指定する設定で、CUDA SDK やカーネルドライバー自体はインストールしない。OS 側の版・配置とコンパイラの互換性は各ホストで確認する。

参考: [NVIDIA CUDA の構成と互換性](https://docs.nvidia.com/deploy/cuda-compatibility/why-cuda-compatibility.html)、[CUDA の導入・ホストコンパイラ要件](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)、[CMake のホストコンパイラ指定](https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_HOST_COMPILER.html)、[clangd の CUDA 対応](https://clangd.llvm.org/faq#does-clangd-support-cuda)。

## Nix 版 GUI の GPU 連携

Fedora のカーネル側 GPU ドライバーは OS 側で管理する。Nix 版 GUI が使う
描画ライブラリは Home Manager の GPU 連携で用意する。この設定は Fedora の
ドライバーをインストール・置換するものではない。

VS Code・Emacs・Alacritty を Nix 管理するため、GPU 連携を有効にしている。
現在は NVIDIA `615.71.09` を固定しているので、別ホストでは適用前に変更する。
Flatpak に移したアプリの描画ライブラリは Flatpak 側で管理される。

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
