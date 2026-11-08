# 検討事項・TODO

今後やること・決めることのメモ。決まったら AGENTS.md に方針として昇格させる(理由の比較・トレードオフは `docs/decisions/` の ADR へ)。解決した項目はここから削除し、蒸し返さないための記録は ADR 側に残す。

## secrets-scan.yml の gitleaks → Betterleaks 移行検討(2026-08時点、保留)

- gitleaks(CLI本体)は開発者が feature-complete を宣言し、今後はセキュリティパッチのみで新機能追加なし。開発リソースは後継の Betterleaks(同じ開発者が MIT ライセンスで新規開発、Aikido Security がスポンサー)へ移行中。
- ただし現状の `.github/workflows/secrets-scan.yml` は Action ではなく CLI 本体をバージョン・チェックサム固定で直接実行する方式のため、gitleaks-action の Node 20 廃止問題(2026年9月)の影響は受けず、動作継続に支障はない。
- Betterleaks は 2026-02 作成、2026-03 に v1.1.1 とまだ非常に新しく、実績が薄い。移行を検討する際は `package-researcher` スキルの基準(upstream のメンテ状況・ライセンス確認)に沿って再調査してから判断する。急ぎではない。

## lint の対象をシェル以外(Lua / Nix)にも広げる(2026-11時点、未着手)

- 現状 `scripts/lint.sh` が見るのはシェルスクリプトだけ。`home/.config/nvim/stylua.toml` があるのに CI は stylua を回しておらず、`nix/*.nix` のフォーマット(nixfmt)・未使用束縛(statix / deadnix)も検査していない。
- 入れるなら、ツールは `nix/home.nix` の `home.packages` に足して(`package-researcher` の手順で調査してから)、`lint.sh` は既存の方針どおり「ツールが無ければ警告してスキップ」にする。CI 側は lint ジョブに Nix を入れるか、apt で入るものに限るかを決める必要がある。
- nixfmt を通すと `nix/home.nix` の整形が大きく変わる可能性があるため、導入時は整形だけのコミットを分ける。

## CI の Nix ストアをキャッシュする(2026-11時点、未着手)

- `home-manager-test` は mdgrid を Rust のソースからビルドするため、Ubuntu / macOS の両方で毎回フルビルドになっている可能性がある。まず実行時間を確認し、長いようなら `nix-community/cache-nix-action` 等でストアをキャッシュする(Action は方針どおりコミットハッシュで固定し、Dependabot の追跡対象に入れる)。
- 下の「nixpkgs に無いツールのビルド結果を共有する」と対象が重なる。各マシンへも配るバイナリキャッシュを採るなら、CI はそこへ push するだけでよく、この項は不要になる。

## nixpkgs に無いツールのビルド結果を各マシンで共有する(2026-11時点、未決定)

- `nix/home.nix` の他のツールは cache.nixos.org からビルド済みが落ちるが、nixpkgs に無い mdgrid だけはソースからビルドしている。nixpkgs-unstable の更新で Rust ツールチェーンが変わるたびに、各マシンと CI でビルドし直しになる(ストレージへの影響は GC で消える一時的なもので、問題はビルド時間)。今後 nixpkgs に無いツールを足すたびに同じことが起きる。
- 本命は mdgrid を nixpkgs に登録すること(mdgrid 側の作業。登録後はこの repo の flake 入力と derivation を消して `pkgs.mdgrid` に置き換える1コミットになる)。ただし「nixpkgs に無いツール全般」の対策にはならない。
- 一般解は、CI(`home-manager-test`。既に Linux / macOS 両方でビルドしている)の結果をバイナリキャッシュへ push し、各マシンの `nix.conf` に `extra-substituters` / `extra-trusted-public-keys` を配ること。候補は Cachix(OSS 向けの無償枠がある外部サービス。署名鍵とトークンをリポジトリの Secrets に置く必要がある)と、`nix copy --to file://` で作った静的キャッシュを GitHub Pages 等に置く方法(外部サービス不要だが容量上限が小さく、署名鍵の管理は同じ)。どちらも daemon 構成では `trusted-users` か `trusted-substituters` の設定が要る。
- 外部サービスのアカウントと鍵が要るため、採るかどうかはユーザーの判断待ち。採るなら `package-researcher` の基準(メンテ状況・ライセンス)で Cachix の action を調べ、ADR を書いてから着手する。GitHub Releases のビルド済みバイナリを `fetchurl` する案は `docs/decisions/mdgrid.md` で退けたとおり(OS ごとのハッシュを手で持ち Dependabot が更新できない)、今回も採らない。

## 個人的なこと・特定の文脈が分かることは一切含めない(最重要ルール)

プロンプトは特に、書いた人物の状況が特定できる文脈が混ざりやすい。このファイルも含め、コミット前に必ず全文精査し、少しでも疑わしければ入れない。
