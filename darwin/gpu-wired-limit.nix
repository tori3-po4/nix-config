{
  # GPU(Metal) が確保できる wired メモリ上限を引き上げる。
  # Apple Silicon のユニファイドメモリでは既定で GPU が使える量が
  # カーネルにより制限されており(16GB 機ではおよそ 10.6GB)、ローカル LLM 等で
  # もっと VRAM 相当を使いたい場合に `iogpu.wired_limit_mb` を上げる。
  #
  # この sysctl は揮発的で再起動するたび 0(=既定値)に戻るため、
  # system.defaults では恒久化できない。root で動く launchd daemon から
  # 起動時(と darwin-rebuild switch のたび)に毎回流して恒久化する。
  #
  # 14336 MB = 14GB。16GB 機なので残り ~2GB を OS/アプリに残す攻めの設定。
  # 他アプリ併用時にメモリ逼迫・スワップが出たら値を下げること。
  launchd.daemons.gpu-wired-limit = {
    serviceConfig = {
      ProgramArguments = [
        "/usr/sbin/sysctl"
        "iogpu.wired_limit_mb=14336"
      ];
      RunAtLoad = true;
    };
  };
}
