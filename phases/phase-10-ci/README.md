# フェーズ10:CI(GitHub Actionsで自動テスト)

> **ゴール**:プルリクエストを作るたびに、コードチェックとテストが自動で実行され、失敗したらマージできない状態にする。

## 1. なぜ学ぶか

- フェーズ7でテストを書きましたが、**実行を忘れたら意味がありません**
- 「自分のPCでは通った」は、他の人の環境や本番で通る保証になりません
- チームで開発するときは、**誰の変更でも、同じ環境で、必ずテストが通っていること** を確認してから取り込みたい
- これを自動化する仕組みが **CI(継続的インテグレーション)** です

## 2. 仕組みの解説

### 2-1. CIとは

**CI(Continuous Integration:継続的インテグレーション)** は、コードの変更を取り込むたびに、自動でビルドやテストを行う習慣と仕組みのことです。

```mermaid
flowchart LR
    A[ブランチで作業] --> B[push / PR作成]
    B --> C{GitHub Actions<br>ruff + pytest}
    C -- 成功 --> D[マージできる]
    C -- 失敗 --> E[マージできない<br>修正して再push]
    E --> B
```

### 2-2. GitHub Actions の構成

| 用語 | 意味 | このアプリでは |
| --- | --- | --- |
| ワークフロー | 自動化の手順をまとめたもの(YAMLファイル) | `.github/workflows/ci.yml` |
| トリガー(`on`) | いつ実行するか | main への push、プルリクエスト |
| ジョブ(`jobs`) | 1台のマシンで行う作業のまとまり | `test` |
| ステップ(`steps`) | ジョブの中の1つ1つの作業 | checkout → Python準備 → インストール → ruff → pytest |
| ランナー | ジョブを実行する仮想マシン | `ubuntu-latest` |

### 2-3. ランナーで何が起きているか

ランナーは、**ジョブのたびに新しく用意される、まっさらなUbuntuマシン** です。
そのため、フェーズ6でVMに対して行ったのと同じように、「コードを取得 → Pythonを準備 → ライブラリをインストール → 実行」をすべてワークフローに書く必要があります。終わったらマシンは破棄されます。

### 2-4. サービスコンテナ

ジョブの中で、PostgreSQL などのコンテナを一緒に起動できます。これにより、**本番と同じ種類のDB** でテストできます。
(SQLiteでは通るのに、PostgreSQLでは失敗する、という違いを早く見つけられます)

### 2-5. リンターとフォーマッター

| 道具 | 役割 |
| --- | --- |
| リンター(`ruff check`) | 使っていない変数・import、バグになりやすい書き方を指摘する |
| フォーマッター(`ruff format`) | インデントや改行などの書き方を自動でそろえる |

書き方の議論をレビューで行う必要がなくなり、**本質的な内容のレビューに集中** できます。

### 2-6. ブランチ保護

GitHubの設定で、「CIが成功しないと main にマージできない」というルールを設定できます。人間の注意力に頼らず、**仕組みで品質を守る** ことができます。

## 3. ハンズオン

```bash
git switch -c feature/ci
```

### Step 1. ruff を導入する

```bash
uv pip install ruff
```

`pyproject.toml` に ruff の設定を追加します(例:[sample/pyproject.toml](sample/pyproject.toml))。

```toml
[tool.ruff]
line-length = 100        # 1行の最大文字数
target-version = "py312"

[tool.ruff.lint]
# E/W: 書き方(pycodestyle)、F: バグの可能性(pyflakes)、I: importの並び順、B: よくあるバグ
select = ["E", "W", "F", "I", "B"]
```

あわせて `requirements-dev.txt` に `ruff` を追加します。

```bash
ruff check .            # 問題点を表示
ruff check . --fix      # 自動で直せるものは直す
ruff format .           # 書き方をそろえる
```

**期待される結果**:最後に `ruff check .` と `ruff format --check .` を実行し、どちらもエラーが出ない。

### Step 2. テストで使うDBを環境変数で切り替える

CIでは PostgreSQL でテストするため、`tests/conftest.py` の `app` フィクスチャを変更します。今まで固定で `"sqlite://"` を指定していた部分を、環境変数があればそちらを使うように書き換えます。

```python
import os

# 変更前
"SQLALCHEMY_DATABASE_URI": "sqlite://",

# 変更後
"SQLALCHEMY_DATABASE_URI": os.environ.get("TEST_DATABASE_URL", "sqlite://"),
```

これは2-7(フェーズ9)で説明した「環境変数があればそれを使い、なければ従来通り」というパターンと同じ考え方です。CI上では環境変数 `TEST_DATABASE_URL` を設定してPostgreSQLに接続し、自分のPCではこれまで通りメモリ上のSQLiteを使います(完成例:[sample/tests/conftest.py](sample/tests/conftest.py))。

### Step 3. ワークフローを作成する

リポジトリのルートに `.github/workflows/ci.yml` を作成します。ワークフローファイルは **YAML** という、インデント(字下げ)で構造を表す記法で書きます。

> **注意**:ワークフローファイルは、**リポジトリのルート直下** の `.github/workflows/` に置かないと動きません。この教材リポジトリの `sample/` の中にあるファイルは、参考用のため実行されません。

まず、「いつ」「どこで」実行するかを書きます。

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
```

- `name`:Actionsタブに表示されるワークフローの名前です
- `on`:トリガー(2-2)。`main`へのpushと、プルリクエストが作られた/更新されたときに実行します
- `jobs`:このワークフローが行うジョブ(2-2)の一覧です。ここでは`test`という名前のジョブを1つだけ定義します
- `runs-on`:どんなランナー(2-3)で実行するかです。`ubuntu-latest`は、GitHubが用意する最新のUbuntu環境を意味します

次に、テスト用のPostgreSQLを**サービスコンテナ**(2-4)として起動する設定を追加します。

```yaml
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: todo
          POSTGRES_PASSWORD: todo
          POSTGRES_DB: todo_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U todo -d todo_test"
          --health-interval 5s
          --health-timeout 3s
          --health-retries 10
```

`services`の中に書いたコンテナは、ジョブの実行中だけ裏側で起動します。`options`のヘルスチェックは、フェーズ9の`compose.yaml`で使った`healthcheck`と同じ役割で、「PostgreSQLが接続を受け付けられる状態になるまで待つ」ための設定です。

最後に、実際の作業を**ステップ**(2-2)として並べます。

```yaml
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: requirements-dev.txt

      - name: Install dependencies
        run: pip install -r requirements-dev.txt

      - name: Lint (ruff)
        run: |
          ruff check .
          ruff format --check .

      - name: Test (pytest)
        env:
          TEST_DATABASE_URL: postgresql+psycopg://todo:todo@localhost:5432/todo_test
        run: pytest --cov=todo_app --cov-report=term-missing
```

- `uses`:他の人(ここではGitHub公式)が作った、再利用可能な処理部品を呼び出します。`actions/checkout`はリポジトリのコードを取得する部品、`actions/setup-python`はPythonを準備する部品です
- `run`:シェルコマンドをそのまま実行します。手元のターミナルで打っていたコマンドと同じものです
- `env`:そのステップだけで使う環境変数です。`TEST_DATABASE_URL`に、サービスコンテナとして起動したPostgreSQLへの接続先を指定しています

完成例:[sample/.github/workflows/ci.yml](sample/.github/workflows/ci.yml)

### Step 4. push して、Actions タブでログを読む

```bash
git add .
git commit -m "GitHub ActionsでCIを追加"
git push -u origin feature/ci
```

GitHubでプルリクエストを作成し、**Actions** タブ(またはPRの **Checks**)を開きます。

**期待される結果**:各ステップが緑のチェックになる。ステップをクリックしてログを開き、手元で実行していたコマンドと同じものが実行されていることを確認する。

### Step 5. わざと失敗させる

1. テストの期待値をわざと間違えて(例:`"牛乳を買う"` → `"牛乳を買わない"`)push する
2. CIが赤くなり、ログのどこで失敗したかを確認する
3. 元に戻して push し、緑に戻ることを確認する

### Step 6. ブランチ保護を設定する

1. リポジトリの **Settings → Branches(または Rules → Rulesets)** を開く
2. `main` を対象に、**Require status checks to pass** を有効にし、`test` ジョブを必須にする
3. CIが失敗するPRを作り、**Merge ボタンが押せない** ことを確認する

### Step 7. マージする

CIが通った状態のプルリクエストをマージします。

## 4. 確認課題

- [ ] README.md に CI のステータスバッジを表示する(Actions → ワークフロー → **…** → **Create status badge**)
- [ ] pip のキャッシュ(`cache: pip`)を外した場合と付けた場合で、「Install dependencies」ステップの実行時間を比べる
- [ ] ワークフローに `docker build .` を実行するステップを追加し、DockerイメージがビルドできることもCIで確認する

## 5. 振り返り

- CIのログに出ている各ステップは、これまで自分のPCやVMで手作業でやっていたことのどれに当たる?
- ブランチ保護を設定すると、チーム開発で何が安心になる?
- テストが通ったコードを、次は **自動で本番に届けたい**。そのために、まずフェーズ6のVMの代わりにどこで動かせばよいだろう?(→ フェーズ11へ)

## このフェーズのファイル

```
sample/
├── .github/workflows/ci.yml   … CIのワークフロー(新規)
├── pyproject.toml             … ruff の設定を追加
├── requirements-dev.txt       … ruff を追加
└── tests/conftest.py          … TEST_DATABASE_URL に対応
```

## よくあるエラー

| エラー・症状 | 原因 | 対処 |
| --- | --- | --- |
| Actions タブに何も表示されない | ワークフローの場所が違う | ルート直下の `.github/workflows/` にあるか確認 |
| `Invalid workflow file` | YAMLのインデントが崩れている | スペースでそろえる(タブは使えない) |
| ruff のステップで失敗する | 手元で format していない | `ruff format .` と `ruff check . --fix` を実行してから push |
| DB接続エラー(CIのみ) | サービスコンテナの起動待ちが足りない、URLの誤り | `options` の health check と `TEST_DATABASE_URL` を確認 |
