# フェーズ4:データベースとTodo CRUD

> **ゴール**:Todoをデータベース(SQLite)に保存し、作成・表示・更新・削除(CRUD)ができる。サーバーを再起動してもデータが残る。

## 1. なぜ学ぶか

- フェーズ3では、サーバーを再起動するとTodoがすべて消えてしまいました。データが **メモリ上** にしかなかったためです
- フェーズ2のようにJSONファイルに保存する方法もありますが、複数人が同時に書き込んだときにデータが壊れたり、「未完了だけ」などの検索が遅くなったりします
- そこで、データを安全に保存・検索するための専用ソフトウェア **データベース** を使います

## 2. 仕組みの解説

### 2-1. データベースとテーブル

データベースは、データを **テーブル**(表)の形で保存します。Excelのような表をイメージすると近いですが、列ごとに入れられるデータの種類(型)が厳密に決まっている点が違います。

**todo テーブル**

| id(主キー) | title | done | created_at |
| --- | --- | --- | --- |
| 1 | 牛乳を買う | 0 | 2026-10-01 10:00 |
| 2 | 本を読む | 1 | 2026-10-01 11:30 |

- **行(レコード)**:1件のデータ
- **列(カラム)**:データの項目。型(文字列・数値など)が決まっている
- **主キー**:行を一意に特定するための列(`id`)

表計算ソフトと違い、列の型が厳密に決まっていること、大量のデータでも高速に検索できること、同時に書き込んでも壊れにくいことが特徴です。

### 2-2. SQL

データベースを操作するための言語が **SQL** です。日本語や英語のような「人間の言葉」ではなく、データベースに「お願いする」ための共通言語だと考えてください。CRUDの4つの操作に対応します。

| 操作 | SQL | 例 |
| --- | --- | --- |
| Create(作成) | INSERT | `INSERT INTO todo (title) VALUES ('牛乳を買う');` |
| Read(読み取り) | SELECT | `SELECT * FROM todo WHERE done = 0;` |
| Update(更新) | UPDATE | `UPDATE todo SET done = 1 WHERE id = 1;` |
| Delete(削除) | DELETE | `DELETE FROM todo WHERE id = 1;` |

### 2-3. アプリとデータベースの関係

アプリとデータベースも、**クライアントとサーバー** の関係です。アプリがSQLを送り、データベースが結果を返します。

```mermaid
sequenceDiagram
    participant B as ブラウザ
    participant F as Flask
    participant D as データベース
    B->>F: POST /todos(title=牛乳)
    F->>D: INSERT INTO todo ...
    D-->>F: OK
    F-->>B: 302 リダイレクト
    B->>F: GET /
    F->>D: SELECT * FROM todo
    D-->>F: Todoの一覧
    F-->>B: 200 OK + HTML
```

> SQLiteはファイル1つで動く軽量なデータベースで、アプリと同じ **プロセス**(実行中のプログラムの1つの単位)の中で動きます。フェーズ9では、独立したサーバーとして動くPostgreSQLに切り替えます。

### 2-4. ORM(SQLAlchemy)

SQLを文字列で書く代わりに、**Pythonのクラスでテーブルを表し、メソッドで操作する** 仕組みが **ORM** です。SQLという「外国語」を知らなくても、母国語(Python)で指示を出せば、裏で通訳者がSQLに翻訳して伝えてくれるようなものだとイメージしてください。

```python
class Todo(db.Model):          # todo テーブル
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)

db.session.add(Todo(title="牛乳"))   # → INSERT INTO todo (title) VALUES ('牛乳')
db.session.commit()
```

- `primary_key=True`:その列が **主キー** であることを示します
- `nullable=False`:その列を空にはできない(必ず値が必要)という意味です
- `db.session.add(...)` は変更を一時的に用意するだけで、`db.session.commit()`(**commit**=「確定する」という意味)を呼ぶまでは実際にはデータベースに保存されません

ORMは魔法ではなく、**裏でSQLを作って送っている** だけです。ハンズオンでは、実際に送られているSQLを確認します。

### 2-5. SQLインジェクション

ユーザーの入力をそのままSQLの文字列に埋め込むと、悪意のある入力でSQLの意味を書き換えられてしまいます。

```python
# 危険な例(絶対に書かない)
sql = f"SELECT * FROM todo WHERE title = '{title}'"
# title に「' OR '1'='1」と入力されると、全件が取得されてしまう
```

ORMやプレースホルダー(`?`)を使うと、入力値は自動で安全に処理されます。プレースホルダーは、データベース側に「ここに入る値はSQLの一部ではなく、ただのデータとして扱ってください」と伝える仕組みです。

## 3. ハンズオン

### Step 1. SQLを手で実行してみる

SQLite のコマンドラインツール `sqlite3` を使います(Macには最初からインストールされています)。ORM(2-4)を使う前に、まず生のSQLでテーブル操作を体験しておくと、後でORMが裏側で何をしているかを理解しやすくなります。

```bash
sqlite3 practice.db
```

[sample/sql/practice.sql](sample/sql/practice.sql) のSQLを1文ずつ貼り付けて実行し、結果を確認します。`.quit` で終了します。

**期待される結果**:INSERT・UPDATE・DELETE のたびに、SELECT の結果が変わる。

> 練習用の `practice.db` は、確認後に削除してください。

### Step 2. Flask-SQLAlchemy をインストールする

**Flask-SQLAlchemy** は、PythonからSQLiteなどのデータベースを操作するためのORMライブラリです。Flask本体と同じく外部のライブラリなので、仮想環境にインストールします。

```bash
uv pip install flask-sqlalchemy
uv pip freeze | grep -iE "flask|sqlalchemy" > requirements.txt
```

### Step 3. モデルを定義する

`app.py` にデータベースの設定と `Todo` クラスを追加し、`db.create_all()` でテーブルを作成します。

```python
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///todo.db"
app.config["SQLALCHEMY_ECHO"] = True   # 実行されたSQLを表示する
db = SQLAlchemy(app)
```

### Step 4. 一覧・追加・削除をDB版に書き換える

フェーズ3でリストを操作していた部分を、データベースの操作に置き換えます。見た目の操作(追加・削除など)は変わりませんが、裏側で起きていることが「メモリ上のリストを書き換える」から「データベースに命令を送る」に変わります。

| フェーズ3(リスト) | フェーズ4(データベース) |
| --- | --- |
| `todos` | `db.session.execute(db.select(Todo)).scalars().all()` |
| `todos.append(...)` | `db.session.add(Todo(...))` + `db.session.commit()` |
| `find_todo(todo_id)` | `db.get_or_404(Todo, todo_id)` |
| `todos.remove(todo)` | `db.session.delete(todo)` + `db.session.commit()` |

完成例:[sample/app.py](sample/app.py)

### Step 5. 実行されるSQLを確認する

```bash
flask --app app run --debug --port 5001
```

ブラウザでTodoを追加し、ターミナルを確認します。

**期待される結果**:`INSERT INTO todo (title, done, created_at) VALUES (?, ?, ?)` のようなSQLが表示される。`?` の部分に入力値が安全に渡されていることも確認しましょう。ORMが裏でどんなSQLを組み立てているかを実際に見ることで、2-4で説明した「ORMは魔法ではない」ということを体感できます。

### Step 6. 完了フラグの更新を実装する

完了・未完了を切り替えるルートを追加します。`done` を反転させて保存するだけなので、これまでの編集・削除と同じ形で書けます。

```python
@app.route("/todos/<int:todo_id>/toggle", methods=["POST"])
def toggle(todo_id):
    """完了・未完了の切り替え:UPDATE todo SET done = ... WHERE id = ..."""
    todo = db.get_or_404(Todo, todo_id)
    todo.done = not todo.done   # True/False を反転させる
    db.session.commit()
    return redirect(url_for("index"))
```

`index.html` の一覧にも、切り替え用のボタンを追加します。削除ボタンと同じく `<form>` + `POST` で実装します(GETのリンクにすると、リンクを開いただけで状態が変わってしまうため)。

```html
<form action="{{ url_for('toggle', todo_id=todo.id) }}" method="post" class="inline">
  <button type="submit">{{ "戻す" if todo.done else "完了" }}</button>
</form>
```

完成例:[sample/app.py](sample/app.py)、[sample/templates/index.html](sample/templates/index.html)

**期待される結果**:一覧で「完了」ボタンを押すと表示が切り替わり、ターミナルに `UPDATE` 文が出る。

### Step 7. 再起動してもデータが残ることを確認する

1. Todoをいくつか追加する
2. `control + C` でサーバーを止め、再度起動する
3. 一覧を開く

**期待される結果**:Todoが残っている。データは `instance/todo.db` に保存されています。

```bash
sqlite3 instance/todo.db "SELECT * FROM todo;"
```

### Step 8. コミットしてpushする

データベースファイルは各自の環境で作られるデータなので、Gitで管理しません。実行するたびに内容が変わるファイルをGitに含めると、他の人と作業したときに余計な差分や衝突の原因になります。`.gitignore` に追加してからコミットします。

```bash
echo "instance/" >> .gitignore
git add .
git status   # instance/ や *.db が含まれていないことを確認
git commit -m "SQLiteでTodoを保存するように変更"
git push
```

## 4. 確認課題

- [ ] Todoに「期限日(due_date)」の列を追加し、期限が近い順に並べて表示する(ヒント:一度 `instance/todo.db` を削除してテーブルを作り直す)
- [ ] 「未完了のみ表示」のリンクを作り、`/?filter=active` で絞り込めるようにする(ヒント:`request.args`、`where`)
- [ ] `sqlite3` コマンドで、アプリから追加したTodoを直接 `UPDATE` し、ブラウザに反映されることを確認する

## 5. 振り返り

- 「追加」ボタンを押してから、データベースにデータが入るまでの流れを説明してみよう
- ORMを使うと、SQLを書かなくてよくなるのはなぜ?裏では何が起きている?
- 今のアプリを家族や友人と一緒に使い始めたら、何が困る?(→ フェーズ5へ)

## このフェーズのファイル

```
sample/
├── app.py              … モデル定義とCRUD処理
├── requirements.txt
├── sql/
│   └── practice.sql    … SQL練習用
├── templates/          … index.html に完了ボタンを追加
└── static/
```

## よくあるエラー

| エラー | 原因 | 対処 |
| --- | --- | --- |
| `no such table: todo` | テーブルが作られていない | `db.create_all()` が実行されているか確認 |
| `no such column: todo.due_date` | モデルに列を追加したが、テーブルは古いまま | `instance/todo.db` を削除して再起動(本番ではマイグレーションを使う) |
| `NOT NULL constraint failed` | 必須の列に値がない | フォームの値が空でないか確認 |
| `RuntimeError: Working outside of application context` | アプリの外でDB操作をした | `with app.app_context():` の中で実行する |
