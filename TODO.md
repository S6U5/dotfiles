# 検討事項・TODO

今後やること・決めることのメモ。決まったら AGENTS.md に方針として昇格させる(理由の比較・トレードオフは `docs/decisions/` の ADR へ)。解決した項目はここから削除し、蒸し返さないための記録は ADR 側に残す。

## secrets-scan.yml の gitleaks → Betterleaks 移行検討(2026-08時点、保留)

- gitleaks(CLI本体)は開発者が feature-complete を宣言し、今後はセキュリティパッチのみで新機能追加なし。開発リソースは後継の Betterleaks(同じ開発者が MIT ライセンスで新規開発、Aikido Security がスポンサー)へ移行中。
- ただし現状の `.github/workflows/secrets-scan.yml` は Action ではなく CLI 本体をバージョン・チェックサム固定で直接実行する方式のため、gitleaks-action の Node 20 廃止問題(2026年9月)の影響は受けず、動作継続に支障はない。
- Betterleaks は 2026-02 作成、2026-03 に v1.1.1 とまだ非常に新しく、実績が薄い。移行を検討する際は `package-researcher` スキルの基準(upstream のメンテ状況・ライセンス確認)に沿って再調査してから判断する。急ぎではない。

## mdgrid を nixpkgs に登録する(2026-11時点、未着手。mdgrid 側の作業)

- 現状は nixpkgs に無いため flake の入力からソースビルドしている(`docs/decisions/mdgrid.md`)。nixpkgs-unstable の更新で Rust ツールチェーンが変わるたびに各マシンと CI でビルドし直しになるが、ビルド時間は許容し、バイナリキャッシュ(Cachix 等)は作らないと決めた(各マシン向けの話。CI の中だけでビルド済みのものを持ち回るのは別で、`docs/decisions/ci-store-cache.md`)(ストレージへの影響は GC で消える一時的なもの)。
- 登録が通ったら、この repo 側は `nix/flake.nix` の入力 `mdgrid` と `extraSpecialArgs` の `mdgrid` を消し、`nix/home.nix` の引数の `mdgrid` を `pkgs.mdgrid` に置き換え、`docs/decisions/mdgrid.md` の履歴に追記する。

## 個人的なこと・特定の文脈が分かることは一切含めない(最重要ルール)

プロンプトは特に、書いた人物の状況が特定できる文脈が混ざりやすい。このファイルも含め、コミット前に必ず全文精査し、少しでも疑わしければ入れない。
