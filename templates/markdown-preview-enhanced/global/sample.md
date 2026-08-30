# サンプル資料集

このファイルは Markdown Preview Enhanced のスタイル確認用サンプルです。
複数の資料タイプを想定した構成になっています。

---

# 1. 社内報告・議事録

## 目的

- 進捗を短く共有する
- 決定事項と次アクションを明確化

## 会議概要

| 項目 | 内容 |
|---|---|
| 日時 | 2026-02-06 10:00-10:45 |
| 参加者 | A / B / C |
| 場所 | オンライン |

## 決定事項

- 新UIのA/Bテストを来週開始
- 旧APIの廃止通知は3/1に送付

## TODO

- [ ] 仕様書の更新
- [x] 広報文面のドラフト作成
- [ ] 影響範囲の確認

> 注意: 次回は数値目標とKPIを必ず添えること。

---

# 2. 企画書・提案書

## 背景

市場の需要が高い一方、オンボーディングの離脱率が高い。

## 提案

1. 初回体験の簡略化
2. チュートリアルの段階分割
3. ヘルプセンターの導線改善

### 期待効果

- コンバージョン +12%
- サポート工数 -20%

### 図（Mermaid）

```mermaid
flowchart LR
  A[初回起動] --> B[簡易セットアップ]
  B --> C[ガイド付き体験]
  C --> D[完了]
```

---

# 3. 技術ドキュメント

## API サンプル

```bash
curl -X POST https://api.example.com/v1/items \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"sample","price":1200}'
```

```json
{
  "id": "itm_123",
  "name": "sample",
  "price": 1200,
  "status": "active"
}
```

## 擬似コード

```python
def calc_score(items):
    total = 0
    for item in items:
        total += item.value * 1.2
    return total
```

---

# 4. 仕様書

## 用語

- **ユーザー**: サービスを利用する個人
- **管理者**: ユーザーを管理する権限を持つ担当者

## 要件

- 1分以内に初期設定が完了すること
- モバイル画面幅 360px で表示崩れがないこと

## 画面遷移

```mermaid
stateDiagram-v2
  [*] --> Login
  Login --> Dashboard
  Dashboard --> Settings
  Settings --> Dashboard
```

---

# 5. 研究ノート・メモ

## アイデア

- 仮説: UIの情報密度を下げると離脱が減る
- 反証: 情報が足りず逆に混乱する可能性

## 参考リンク

- <https://example.com>

---

# 6. チェックリスト

- [x] 目的の明確化
- [x] ペルソナの想定
- [ ] ページ構成のレビュー
- [ ] コピーの最終確認

---

# 7. データ・表

| 指標 | 現状 | 目標 |
|---|---:|---:|
| CVR | 2.1% | 2.8% |
| 継続率 | 43% | 55% |
| NPS | 14 | 25 |

---

# 8. 画像

![サンプル画像](https://placehold.co/1200x600/png)

---

# 9. 強調表現

**太字** / *斜体* / ~~取り消し~~ / `インラインコード`

---

# 10. 図表集（Mermaid & PlantUML）

## フローチャート（Mermaid）

```mermaid
flowchart TD
  Start([開始]) --> Input[/データ入力/]
  Input --> Validate{バリデーション}
  Validate -->|OK| Process[処理実行]
  Validate -->|NG| Error[エラー表示]
  Error --> Input
  Process --> Save[(DB保存)]
  Save --> Notify[[通知送信]]
  Notify --> End([完了])
```

## シーケンス図（Mermaid）

```mermaid
sequenceDiagram
  participant U as ユーザー
  participant F as フロントエンド
  participant A as APIサーバー
  participant D as データベース
  participant C as キャッシュ

  U->>F: ログインボタン押下
  F->>A: POST /auth/login
  A->>D: ユーザー照会
  D-->>A: ユーザー情報
  A->>A: トークン生成
  A->>C: セッション保存
  A-->>F: 200 OK + JWT
  F->>F: トークン保存
  F-->>U: ダッシュボード表示

  Note over U,C: 以降のリクエスト

  U->>F: データ取得
  F->>A: GET /api/data (Bearer)
  A->>C: キャッシュ確認
  alt キャッシュあり
    C-->>A: キャッシュデータ
  else キャッシュなし
    A->>D: クエリ実行
    D-->>A: 結果
    A->>C: キャッシュ保存
  end
  A-->>F: JSON レスポンス
  F-->>U: データ表示
```

## クラス図（Mermaid）

```mermaid
classDiagram
  class User {
    +String id
    +String name
    +String email
    +Role role
    +login()
    +logout()
  }

  class Admin {
    +manageUsers()
    +viewReports()
  }

  class Article {
    +String id
    +String title
    +String body
    +Status status
    +publish()
    +archive()
  }

  class Comment {
    +String id
    +String text
    +DateTime createdAt
  }

  class Tag {
    +String name
  }

  User <|-- Admin
  User "1" --> "*" Article : 投稿
  Article "1" --> "*" Comment : 含む
  User "1" --> "*" Comment : 書く
  Article "*" --> "*" Tag : 分類
```

## ER図（Mermaid）

```mermaid
erDiagram
  USERS {
    uuid id PK
    varchar name
    varchar email UK
    timestamp created_at
  }

  ORDERS {
    uuid id PK
    uuid user_id FK
    decimal total
    varchar status
    timestamp ordered_at
  }

  ORDER_ITEMS {
    uuid id PK
    uuid order_id FK
    uuid product_id FK
    int quantity
    decimal price
  }

  PRODUCTS {
    uuid id PK
    varchar name
    decimal price
    int stock
    uuid category_id FK
  }

  CATEGORIES {
    uuid id PK
    varchar name
    varchar slug
  }

  USERS ||--o{ ORDERS : "注文する"
  ORDERS ||--|{ ORDER_ITEMS : "含む"
  PRODUCTS ||--o{ ORDER_ITEMS : "含まれる"
  CATEGORIES ||--o{ PRODUCTS : "分類する"
```

## ガントチャート（Mermaid）

```mermaid
gantt
  title プロジェクトスケジュール
  dateFormat YYYY-MM-DD
  axisFormat %m/%d

  section 企画
    要件定義       :done, req, 2026-02-01, 7d
    技術調査       :done, research, 2026-02-03, 5d

  section 設計
    DB設計         :active, db, 2026-02-08, 5d
    API設計        :api, after db, 4d
    UI設計         :ui, 2026-02-08, 7d

  section 開発
    バックエンド    :backend, after api, 14d
    フロントエンド  :frontend, after ui, 14d
    結合           :integration, after backend, 5d

  section テスト
    単体テスト      :unit, after backend, 7d
    E2Eテスト      :e2e, after integration, 5d
    リリース       :milestone, release, after e2e, 0d
```

## 円グラフ（Mermaid）

```mermaid
pie title 技術スタック使用割合
  "TypeScript" : 40
  "Python" : 25
  "Go" : 15
  "Rust" : 10
  "その他" : 10
```

## Git グラフ（Mermaid）

```mermaid
gitgraph
  commit id: "initial"
  commit id: "setup"
  branch feature/auth
  checkout feature/auth
  commit id: "add login"
  commit id: "add JWT"
  checkout main
  branch feature/ui
  checkout feature/ui
  commit id: "header"
  commit id: "sidebar"
  checkout main
  merge feature/auth id: "merge auth"
  checkout feature/ui
  commit id: "responsive"
  checkout main
  merge feature/ui id: "merge ui"
  commit id: "v1.0" tag: "release"
```

## タイムライン（Mermaid）

```mermaid
timeline
  title プロダクト進化
  2024 : MVP リリース
       : ユーザー100人達成
  2025 : API v2 公開
       : モバイルアプリ
       : ユーザー10,000人
  2026 : AI機能統合
       : 多言語対応
       : エンタープライズ版
```

## マインドマップ（Mermaid）

```mermaid
mindmap
  root((Webアプリ))
    フロントエンド
      React
      TypeScript
      Tailwind CSS
      Storybook
    バックエンド
      Node.js
      Express
      PostgreSQL
      Redis
    インフラ
      AWS
      Docker
      Terraform
      GitHub Actions
    品質
      Jest
      Playwright
      ESLint
      Prettier
```

---

## シーケンス図（PlantUML）

```plantuml
@startuml
skinparam style strictuml
skinparam backgroundColor #FEFEFE

actor ユーザー as U
participant "Webブラウザ" as B
participant "APIゲートウェイ" as GW
participant "認証サービス" as Auth
participant "注文サービス" as Order
database "DB" as DB
queue "メッセージキュー" as MQ

U -> B : 注文ボタン押下
B -> GW : POST /orders
GW -> Auth : トークン検証
Auth --> GW : OK

GW -> Order : 注文作成
Order -> DB : INSERT
DB --> Order : 注文ID

Order -> MQ : 注文イベント発行
MQ --> Order : ACK

Order --> GW : 201 Created
GW --> B : 注文完了
B --> U : 完了画面表示

... 非同期処理 ...

MQ -> Order : 在庫確認
Order -> DB : UPDATE (確定)
@enduml
```

## クラス図（PlantUML）

```plantuml
@startuml
skinparam classAttributeIconSize 0

package "Domain" {
  abstract class Entity {
    # id: UUID
    # createdAt: DateTime
    # updatedAt: DateTime
  }

  class User extends Entity {
    - name: String
    - email: Email
    - passwordHash: String
    + authenticate(password): Boolean
    + changeEmail(newEmail): void
  }

  class Order extends Entity {
    - items: List<OrderItem>
    - status: OrderStatus
    + addItem(product, qty): void
    + calculateTotal(): Money
    + confirm(): void
    + cancel(): void
  }

  class OrderItem {
    - product: Product
    - quantity: Int
    - unitPrice: Money
    + subtotal(): Money
  }

  class Product extends Entity {
    - name: String
    - price: Money
    - stock: Int
    + isAvailable(): Boolean
    + decreaseStock(qty): void
  }

  enum OrderStatus {
    PENDING
    CONFIRMED
    SHIPPED
    DELIVERED
    CANCELLED
  }
}

User "1" -- "*" Order : 注文する >
Order *-- "1..*" OrderItem
OrderItem --> Product
Order --> OrderStatus

@enduml
```

## アクティビティ図（PlantUML）

```plantuml
@startuml
start

:ユーザーがフォーム送信;

if (バリデーション) then (OK)
  :データ正規化;

  fork
    :メール送信;
  fork again
    :DB保存;
  fork again
    :ログ記録;
  end fork

  if (全処理成功？) then (はい)
    :完了画面表示;
    #palegreen:成功;
  else (いいえ)
    :リトライキューに追加;
    #lightyellow:部分成功;
  endif

else (NG)
  :エラーメッセージ表示;
  #pink:失敗;
  stop
endif

stop
@enduml
```

## コンポーネント図（PlantUML）

```plantuml
@startuml
skinparam component {
  BackgroundColor #F5F5F5
  BorderColor #333333
}

package "フロントエンド" {
  [SPA (React)] as SPA
  [状態管理 (Zustand)] as State
  [UIコンポーネント] as UI
}

package "バックエンド" {
  [API サーバー] as API
  [認証モジュール] as Auth
  [ビジネスロジック] as BL
}

package "データ層" {
  database "PostgreSQL" as PG
  database "Redis" as Redis
  storage "S3" as S3
}

cloud "外部サービス" {
  [メール (SES)] as Mail
  [決済 (Stripe)] as Pay
}

SPA --> API : REST / WebSocket
SPA --> State
SPA --> UI

API --> Auth
API --> BL
BL --> PG
BL --> Redis
BL --> S3
BL --> Mail
BL --> Pay
@enduml
```

## 状態遷移図（PlantUML）

```plantuml
@startuml
skinparam state {
  BackgroundColor #FAFAFA
  BorderColor #666666
}

[*] --> Draft : 作成

state Draft {
  [*] --> Editing
  Editing --> Reviewing : レビュー依頼
  Reviewing --> Editing : 差し戻し
}

Draft --> Published : 公開
Published --> Archived : アーカイブ
Published --> Draft : 非公開に戻す
Archived --> Published : 再公開
Archived --> [*] : 削除

@enduml
```

---

# 11. 強調表現

**太字** / *斜体* / ~~取り消し~~ / `インラインコード`

---

# 12. 水平線

---

以上。
