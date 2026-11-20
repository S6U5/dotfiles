# lint・フォーマットのツール

`scripts/lint.sh` が何を検査し、CI でどの版を使うか。

## 選んだもの

| 対象 | ツール | 選んだ理由 |
| --- | --- | --- |
| シェル | shellcheck / shfmt | 事実上の標準 |
| Lua | stylua | Lua のフォーマッターの事実上の標準。LazyVim の雛形が `stylua.toml` を同梱している |
| Nix | nixfmt | Nix 公式(NixOS の formatting チームが保守する公式のフォーマッター) |
| GitHub Actions | actionlint | ワークフローの lint の事実上の標準。`run:` の中のシェルも shellcheck に通す |

基準は「公式のものか、広く使われているもの」。

## 入れなかったもの

- **statix**(Nix の書き方の lint): 本家が GitHub から別のホスティングへ移り、nixpkgs は別のフォークをビルドしている。導入時点の指摘も好みの問題の1件だけだった。
- **deadnix**(Nix の未使用の束縛): 指摘は 0 件で、`nix/` は数ファイルしかない。公式のツールでもないので、必要になってから入れる。
- **taplo**(TOML): 検査のたびにスキーマを外から取りに行き、取れないと失敗する。TOML の誤りは読む側のツールがすぐ報告する。
- **Markdown の lint**: 文書は日本語の散文が中心で、機械的な規則で得るものが少ない。

## CI で使う版

- lint ジョブにも Nix を入れ、`nix shell --inputs-from ./nix nixpkgs#...` で `nix/flake.lock` の nixpkgs からツールを取る。手元(`nix/home.nix` の `home.packages`)と同じ版になる。
- apt で入れる案は採らなかった。フォーマッターは版で出力が変わり、apt の版は nixpkgs より古いので、手元で通った整形が CI で落ちる(またはその逆)ことが起きる。
- CI(環境変数 `CI` がある)では、ツールが無いことも失敗にする。ワークフローのツール一覧と `lint.sh` がずれても、検査が黙って飛ばされない。手元では従来どおり警告して飛ばす。

## トレードオフ

- lint ジョブが Nix の導入とツールの取得のぶん長くなる。
- Dependabot が nixpkgs を上げたときにフォーマッターの出力が変わると、その PR の lint が落ちる。`./scripts/lint.sh --fix` の結果を同じ PR に足して直す。
