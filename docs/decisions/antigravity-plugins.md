# Antigravity へのプラグインの届け方

Antigravity(Antigravity / Antigravity CLI / IDE)は Marketplace の目録を経由せず、`~/.gemini/config/plugins/` に置いたプラグインのルート直下 `plugin.json` を直接読む。同梱プラグインをここへどう置くかの決定。

## 検討した代替

- **対応しない**(常用ツールではないため)
- **`agy plugin install <パス>` で導入する**(公式の導入コマンド)
- **Antigravity 専用のマニフェストを各プラグインに追加する**(`https://antigravity.google/schemas/v1/plugin.json`)
- **`~/.gemini/config/plugins/<名前>` にシンボリックリンクを張る**(採用。`agent-plugins-setup` が行う)

## 選んだ理由

- 既存のルート直下 `plugin.json`(Agent Plugins 1.0 標準)がそのまま `agy plugin validate` を通り、スキルも認識された。専用マニフェストは不要で、対応のコストはリンク1本で済む。
- `agy plugin install` は実体を**コピー**するため、リポジトリを編集しても反映されない(`git pull` のたびに入れ直しになる)。リンクなら Cursor と同じく編集が即反映され、リンクを外すと認識されなくなることも確認した(=読まれているのはリンク先)。
- Antigravity の三者のうち `~/.gemini/config/plugins/` だけが共通の置き場で、他の置き場は一部でしか読まれない。

## トレードオフ

- `agy plugin list` の導入記録には載らないため、`agy plugin enable` / `disable` / `uninstall` がリンクに対してどう振る舞うかは未確認。撤去はリンクを消して行う(`uninstall` はリンク先の実体を消しうるので使わない)。
- 適用先を選ぶ設定は作らない。他のエージェントと同じく、Antigravity が見つかった環境では常に導入する。
