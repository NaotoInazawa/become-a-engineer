# フェーズ9:Dockerによるコンテナ化

> **ゴール**:アプリとデータベース(PostgreSQL)をDocker Composeで定義し、`docker compose up` の1コマンドで誰の環境でも同じように起動できる。

## 1. なぜ学ぶか

- フェーズ6では、VMにPython・ライブラリ・設定を **手作業で** 1つずつ準備しました。手順が多く、1つ間違えると動きませんでした
- 「自分のPCでは動くのに、サーバーや他の人のPCでは動かない」という問題は、Pythonのバージョンやライブラリ、OSの違いから起きます
- 本番で使われることの多い **PostgreSQL** を使いたいが、PCに直接インストールして環境を汚したくない
- **Docker** を使うと、アプリと実行環境を「箱(コンテナ)」に詰めて、どこでも同じように動かせます

## 2. 仕組みの解説

### 2-1. コンテナとは

```mermaid
flowchart TB
    subgraph VMの場合
        direction TB
        HW1[物理マシン] --> HV[ハイパーバイザー]
        HV --> OS1[ゲストOS<br>Ubuntu 丸ごと]
        OS1 --> A1[アプリ]
    end
    subgraph コンテナの場合
        direction TB
        HW2[PC / サーバー] --> OS2[ホストOS]
        OS2 --> DE[Docker]
        DE --> C1[コンテナ<br>Python + アプリ]
        DE --> C2[コンテナ<br>PostgreSQL]
    end
```

| | VM(フェーズ6) | コンテナ |
| --- | --- | --- |
| 中身 | OSを丸ごと持つ | アプリと必要なライブラリだけ |
| 起動時間 | 数十秒〜数分 | 数秒 |
| サイズ | 数GB | 数十MB〜数百MB |
| 環境の再現 | 手作業の手順書 | Dockerfile(コード) |

### 2-2. イメージとコンテナ

| | 意味 | 例え |
| --- | --- | --- |
| **イメージ** | アプリと実行環境をまとめた「設計図」。読み取り専用 | レシピ・型 |
| **コンテナ** | イメージから起動した「実体」。何個でも作れる | 型から作ったお菓子 |
| **Dockerfile** | イメージの作り方を書いたファイル | レシピの手順書 |

### 2-3. Dockerfile は「フェーズ6の手順書」をコードにしたもの

| フェーズ6の手作業 | Dockerfile |
| --- | --- |
| Ubuntu の VM を作成する | `FROM python:3.12-slim` |
| `cd ~/my-todo-app` | `WORKDIR /app` |
| `git clone` | `COPY . .` |
| `pip install -r requirements.txt` | `RUN pip install -r requirements.txt` |
| systemd で gunicorn を起動する | `CMD ["gunicorn", ...]` |

### 2-4. ポートマッピング

コンテナは、ホストPCから隔離された **専用のネットワーク** を持っています。外からアクセスするには、ホストのポートとコンテナのポートをつなぐ必要があります。

```mermaid
flowchart LR
    B[ブラウザ<br>localhost:8000] --> H[ホストPCの<br>8000番]
    H -- ポートマッピング<br>8000:8000 --> C[webコンテナの<br>8000番<br>gunicorn]
    C -- db:5432 --> D[dbコンテナの<br>5432番<br>PostgreSQL]
```

> フェーズ6では gunicorn を `127.0.0.1` で待ち受けましたが、コンテナでは `0.0.0.0` で待ち受けます。コンテナの外(ホストPC)から届くリクエストを受け付ける必要があるためです。外部に公開するかどうかは、ポートマッピングで制御します。

### 2-5. ボリューム

コンテナを削除すると、コンテナの中で作られたファイルも消えます。DBのデータのように残したいものは、**ボリューム**(コンテナの外の保存領域)に保存します。

### 2-6. Docker Compose

複数のコンテナ(アプリ・DB)の設定を `compose.yaml` にまとめ、一括で起動・停止する仕組みです。
Compose で起動したコンテナ同士は、**サービス名**(`db` など)をホスト名として通信できます。

### 2-7. 環境変数による設定の切り替え

同じコードを、開発ではSQLite、Docker ではPostgreSQL、本番ではクラウドのDBにつなげるため、接続先を **環境変数 `DATABASE_URL`** で渡します。

```python
SQLALCHEMY_DATABASE_URI=os.environ.get("DATABASE_URL", "sqlite:///todo.db")
```

## 3. ハンズオン

### Step 1. Docker をインストールする

[Docker Desktop](https://www.docker.com/products/docker-desktop/) をインストールします。ダウンロード時は、フェーズ0で確認したチップに合わせて **Apple Silicon 版** か **Intel 版** を選びます(Homebrew の場合は `brew install --cask docker`)。

インストール後、アプリケーションフォルダから **Docker** を起動し、メニューバーにクジラのアイコンが表示されるまで待ちます。

```bash
docker --version
docker compose version
```

> Docker Desktop は、個人利用や小規模な組織では無料ですが、一定規模以上の企業での業務利用には有料のサブスクリプションが必要です。会社のMacで学習する場合は、利用条件を確認してください。
>
> Apple シリコンのMacでは、コンテナは **arm64** 版のイメージで動きます。`python:3.12-slim` や `postgres:16` は両方に対応しているため、そのまま使えます(クラウドに持っていくときの注意はフェーズ11で扱います)。

### Step 2. 既成のイメージを動かしてみる

```bash
docker run --rm -p 8080:80 nginx
```

**期待される結果**:ブラウザで `http://localhost:8080` を開くと、nginx の歓迎ページが表示される。フェーズ6でVMにインストールしたnginxが、**1コマンドで** 動きました。`control + C` で停止します。

`-p 8080:80` を `-p 9090:80` に変えると、どのURLで表示されるか試してみましょう。

### Step 3. アプリを PostgreSQL に対応させる

```bash
git switch -c feature/docker
pip install "psycopg[binary]"
```

- `requirements.txt` に `psycopg[binary]` を追加する
- `todo_app/__init__.py` で、DBの接続先を環境変数 `DATABASE_URL` から読むようにする(2-7)

### Step 4. Dockerfile を書く

[sample/Dockerfile](sample/Dockerfile) と [sample/.dockerignore](sample/.dockerignore) を作成します。2-3 の表と見比べながら、各行がフェーズ6のどの作業に当たるかを確認しましょう。

### Step 5. イメージをビルドしてコンテナで起動する

```bash
docker build -t my-todo-app .
docker images                     # イメージができたことを確認
docker run --rm -p 8000:8000 --env-file .env my-todo-app
```

**期待される結果**:`http://localhost:8000` でアプリが表示される(この時点ではコンテナ内のSQLiteを使っている)。

コンテナを止めて、もう一度起動するとデータはどうなるでしょうか?(ヒント:2-5)

### Step 6. Docker Compose でアプリと PostgreSQL を起動する

[sample/compose.yaml](sample/compose.yaml) を作成し、起動します。

```bash
docker compose up --build
```

**期待される結果**:`web` と `db` の2つのコンテナが起動し、`http://localhost:8000` でアプリが使える。

別のターミナルで状態を確認します。

```bash
docker compose ps                      # 起動中のコンテナ一覧
docker compose logs web                # web のログ
docker compose exec db psql -U todo -d todo -c 'SELECT * FROM todo;'   # DBの中身
```

### Step 7. ボリュームでデータが残ることを確認する

```bash
docker compose down        # コンテナを削除(ボリュームは残る)
docker compose up          # 再度起動
```

**期待される結果**:登録したユーザーやTodoが残っている。

```bash
docker compose down -v     # -v を付けるとボリュームも削除される(データが消える)
```

### Step 8. コンテナの中でテストを実行する

```bash
docker compose run --rm web sh -c "pip install --user -r requirements-dev.txt && python -m pytest"
```

**期待される結果**:自分のPCにPythonの環境がなくても、コンテナの中でテストが通る。

### Step 9. 別の場所から起動できるか確認する

```bash
git add .
git commit -m "Docker Composeで起動できるようにする"
git push -u origin feature/docker
cd /tmp
git clone -b feature/docker https://github.com/あなたのユーザー名/my-todo-app.git docker-check
cd docker-check
cp .env.example .env    # SECRET_KEY を設定する
docker compose up --build
```

**期待される結果**:Python や PostgreSQL のインストールなしで、アプリが起動する。確認後、プルリクエストでマージします。

## 4. 確認課題

- [ ] DB管理ツール **Adminer**(`adminer` イメージ)を `compose.yaml` に追加し、ブラウザからDBのテーブルとデータを確認する
- [ ] `Dockerfile` の `COPY requirements.txt .` と `RUN pip install` を `COPY . .` の後ろに移動し、コードを1行変えたときのビルド時間の違いを比べる。なぜ差が出るか説明する(確認後は元に戻す)
- [ ] `docker compose exec web sh` でコンテナに入り、`whoami` と `ls` を実行する。root ではなく `appuser` で動いている理由を説明する

## 5. 振り返り

- フェーズ6の手作業のうち、Dockerfile で自動化できたものと、まだできていないもの(ファイアウォール、HTTPS など)は?
- `DATABASE_URL` を環境変数にしたことで、何ができるようになった?
- Step 8 でテストを実行しましたが、毎回自分で実行するのを忘れたことはない?(→ フェーズ10へ)

## このフェーズのファイル

```
sample/
├── Dockerfile        … アプリのイメージの作り方(新規)
├── .dockerignore     … イメージに含めないファイル(新規)
├── compose.yaml      … web と db をまとめて起動する設定(新規)
├── requirements.txt  … psycopg を追加
└── todo_app/__init__.py … DATABASE_URL を環境変数から読む
```

> フェーズ6・7の `deploy/`(nginx・systemd)は、VMを削除したため以降のサンプルには含めていません。

## よくあるエラー

| エラー・症状 | 原因 | 対処 |
| --- | --- | --- |
| `Cannot connect to the Docker daemon` | Docker Desktop が起動していない | Docker Desktop を起動し、メニューバーのクジラのアイコンが落ち着くまで待つ |
| ビルドやディスクが極端に遅い・容量不足 | 古いイメージやキャッシュがたまっている | `docker system df` で確認し、`docker system prune` で削除 |
| `port is already allocated` | ホストの8000番を別のプロセスが使っている | 他のサーバーを止めるか、`"8001:8000"` に変える |
| `connection refused`(db) | DBの起動前にwebが接続した | `depends_on` の `condition: service_healthy` を確認する |
| `KeyError: 'SECRET_KEY'` / `SECRET_KEY が設定されていません` | `.env` がない | `cp .env.example .env` して値を設定する |
| コードを変えても反映されない | イメージを作り直していない | `docker compose up --build` |
