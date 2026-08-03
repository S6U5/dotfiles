-- このdotfilesリポジトリは home/ 以下がほぼ全てドットファイル(.zshenv, .config 等)なので、
-- Explorer・ファイル検索(<leader>ff 等)でもデフォルトで隠しファイルを表示するようにする。
-- (その場だけ切り替えたい場合は Alt+h で従来どおりトグル可能)
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = { hidden = true },
          files = { hidden = true },
        },
      },
    },
  },
}
