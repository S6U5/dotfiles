# git 設定テンプレート

`.gitconfig.template` は全マシン共通の git 設定(機密・個人情報は含まない)。

## セットアップ

1. `.gitconfig.template` を `~/.gitconfig` にコピーする。

   ```sh
   cp templates/git/.gitconfig.template ~/.gitconfig
   ```

2. `~/.gitconfig.local` を作成し、名前・メールアドレス等マシン固有・個人情報を書く。

   ```gitconfig
   [user]
       name = あなたの名前
       email = あなたのメールアドレス
   ```

   `~/.gitconfig.local` は `~/.gitconfig` の末尾で `[include]` されているため、
   後から読み込まれてこちらの設定が優先される。ファイルが無ければ黙って無視される。

`delta`(git diff のシンタックスハイライトページャ)を使う設定を含んでいるが、
`delta` コマンドが無い環境でも `less` にフォールバックするため、
`nix/home.nix` の `home.packages` に `delta` を入れていなくても壊れない。

## なぜ home/ 自動リンクではなくテンプレート配布なのか

判断根拠: `docs/decisions/gitconfig-management.md`。
