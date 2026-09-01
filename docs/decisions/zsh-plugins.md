# zsh プラグインの読み込み元

zsh-autosuggestions / zsh-syntax-highlighting(Nix の `home.packages` で導入)を zshrc が
どこから source するかの決定(2026-09)。

## 検討した代替

1. **`~/.nix-profile` のレイアウト決め打ち**(旧方式。`~/.nix-profile/share/zsh/plugins/...` 等を zshrc にハードコード)
2. **`programs.zsh.plugins`**(home-manager の設定生成)
3. **`home.file`(`source`)で store パスへのリンクを `~/.config/zsh/plugins/` に配布**(採用)
4. **`home.file`(`text`)で store パスを source する zsh スニペットを生成**

## 選んだ理由

- 案1はプロファイルのレイアウト(パッケージごとに `share/zsh/plugins/...` だったり `share/<名前>/...` だったりする)の推測であり、nixpkgs 側の変更で壊れたとき、zshrc の存在チェックが「エラーも出さず静かに無効化」してしまい気づけない。
- 案2(home-manager の設定生成モジュール)は「switch 未実行時に zsh 設定全体が効かなくなる」past failure により不採用が確定済み(`zshrc-pollution.md` の履歴参照)。
- 案3なら読み込むファイルと導入したパッケージが構造的に一致し(herdr スキルの配布と同じパターン)、flake.lock の更新に自動追従する。zshrc は安定パス(`~/.config/zsh/plugins/...`)だけを知ればよく、レイアウト知識は `nix/home.nix` に一箇所化される。壊れ方も「リンクが宙に浮く」に変わるため、`scripts/test-home-manager.sh`(リンク先の実在・非空チェック)で CI 検出できる。
- 案4は zsh-syntax-highlighting の「.zshrc の一番最後に読み込む」制約のため生成ファイルを2つに分割する必要があり、案3より遠回り。

## トレードオフ

- `home.file` の `source` に書くサブパスは Nix 評価時に検証されない(壊れても build は成功する)ため、検出はテスト頼み。上記のとおり `test-home-manager.sh` に組み込んで補った。
- ディレクトリごとリンクしているため、プラグインが同梱ファイル(highlighters 等)を相対参照しても壊れない。
