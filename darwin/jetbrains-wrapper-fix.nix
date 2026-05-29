# nixpkgs の jetbrains.* on darwin が使う `open -na ... --args "$@"` ラッパーは、
# launchd 経由の CWD 伝達が日本語パス（特に濁点付きカタカナ等）で壊れ、Rust
# ネイティブランチャーが起動時 chdir で ENOENT になる。
# ここで CWD を $HOME に切り替えてから open -n を呼ぶ形に置き換え、launchd 境界
# に渡る CWD を ASCII に保つ。argv 側は呼び出し元 CWD で絶対化してから渡す。
# TODO: 上流 nixpkgs に PR を出して不要にする。
{ ... }:
{
  nixpkgs.overlays = [
    (final: prev:
      let
        fixJBWrapper =
          appName: binName: pkg:
          pkg.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              cat > $out/bin/${binName} <<EOF
              #!/usr/bin/env bash
              new_args=()
              for arg in "\$@"; do
                case "\$arg" in
                  /*) new_args+=("\$arg") ;;
                  .)  new_args+=("\$PWD") ;;
                  *)  new_args+=("\$PWD/\$arg") ;;
                esac
              done
              [ \''${#new_args[@]} -eq 0 ] && new_args=("\$PWD")
              cd "\$HOME" || cd /tmp || cd /
              exec /usr/bin/open -na "$out/Applications/${appName}" --args "\''${new_args[@]}"
              EOF
              chmod +x $out/bin/${binName}
            '';
          });
      in
      {
        jetbrains = prev.jetbrains // {
          idea = fixJBWrapper "IntelliJ IDEA.app" "idea" prev.jetbrains.idea;
          pycharm = fixJBWrapper "PyCharm.app" "pycharm" prev.jetbrains.pycharm;
          clion = fixJBWrapper "CLion.app" "clion" prev.jetbrains.clion;
        };
      }
    )
  ];
}
