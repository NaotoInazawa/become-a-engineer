# Todo API 仕様書

## 共通

- ベースURL:`/api`
- リクエスト・レスポンスの形式:JSON(`Content-Type: application/json`)
- 認証:ログイン時に発行されるセッションCookie。未ログインの場合は `401` を返す

### エラーレスポンス

```json
{
  "error": "Bad Request",
  "message": "title は必須です"
}
```

| ステータス | 意味 |
| --- | --- |
| 400 Bad Request | リクエストの内容が不正 |
| 401 Unauthorized | ログインしていない |
| 403 Forbidden | 他のユーザーのTodoを操作しようとした |
| 404 Not Found | Todoが存在しない |

### Todo オブジェクト

| 項目 | 型 | 説明 |
| --- | --- | --- |
| id | number | TodoのID |
| title | string | タイトル(1〜100文字) |
| done | boolean | 完了していれば `true` |
| created_at | string | 作成日時(ISO 8601形式) |

## エンドポイント一覧

| メソッド | パス | 説明 | 成功時 |
| --- | --- | --- | --- |
| GET | `/api/todos` | 自分のTodo一覧を取得 | 200 |
| POST | `/api/todos` | Todoを追加 | 201 |
| GET | `/api/todos/{id}` | Todoを1件取得 | 200 |
| PUT | `/api/todos/{id}` | Todoを更新 | 200 |
| DELETE | `/api/todos/{id}` | Todoを削除 | 204 |

### GET /api/todos

レスポンス例(200):

```json
[
  {"id": 1, "title": "牛乳を買う", "done": false, "created_at": "2026-10-01T10:00:00"}
]
```

### POST /api/todos

リクエスト:

```json
{"title": "牛乳を買う"}
```

レスポンス例(201):

```json
{"id": 1, "title": "牛乳を買う", "done": false, "created_at": "2026-10-01T10:00:00"}
```

### PUT /api/todos/{id}

`title` と `done` のうち、変更したい項目だけを送ります。

リクエスト:

```json
{"done": true}
```

レスポンス例(200):

```json
{"id": 1, "title": "牛乳を買う", "done": true, "created_at": "2026-10-01T10:00:00"}
```

### DELETE /api/todos/{id}

レスポンス:204(本文なし)
