# 未経験者向け Webアプリ開発教材

エンジニア未経験の方が、ひとりで「Webアプリを作り、テストし、クラウドに公開し、自動でデプロイする」ところまで到達するための教材です。
1つのTodoアプリを13のフェーズで少しずつ育てながら、各技術が **なぜ必要なのか** と **どういう仕組みで動いているのか** を理解することを目指します。

## この教材の特徴

- **困りごとから学ぶ**:各フェーズは「前のフェーズで困ったこと」から始まり、それを解決する技術を学びます
- **デプロイを3回体験する**:GitHub Pages → 仮想サーバー(手動)→ クラウド(自動)と、回を追うごとに裏側の仕組みが自動化されていく流れを体験します
- **全フェーズ共通の構成**:「なぜ学ぶか → 仕組みの解説 → ハンズオン → 確認課題 → 振り返り」の5ステップで進みます

## 教材の読み方

### 各フェーズREADMEの構成

各フェーズの `README.md` は、必ず次の5つのパートで構成されています(詳しい執筆ルールは [docs/template.md](docs/template.md) を参照)。

| パート | 役割 | 読者が行うこと |
| --- | --- | --- |
| 1. なぜ学ぶか | 前フェーズで困ったことと、このフェーズで学ぶ技術のつながりを示す | まず読んで、目的を把握する |
| 2. 仕組みの解説 | 専門用語や図を使って、技術の仕組みを説明する | 手を動かす前に読んで理解する |
| 3. ハンズオン | 実際に手を動かす手順(Step形式) | 1つずつ順番に実行する |
| 4. 確認課題 | ハンズオンの応用問題(ゴールのみ提示。手順はあえて書かない) | 自力で実装してみる |
| 5. 振り返り | 理解度を確認する問い | 自分の言葉で答えを書き出す |

各フェーズ末尾には、`sample/` のファイル構成の説明と「よくあるエラー」の一覧も付いています。エラーが出たら、まずそこを確認してください。

### コードブロックの見分け方

README内のコードブロックは、先頭に書かれた言語名によって「何をするものか」が変わります。

| 表示 | 意味 | すること |
| --- | --- | --- |
| `bash` | ターミナルに入力するコマンド | そのままコピーして実行する |
| `python` | エディタで書くPythonコードの一部 | ファイルに書き写す |
| `html` / `css` / `javascript` | エディタで書くHTML/CSS/JSコードの一部 | ファイルに書き写す |
| `mermaid` | 図(仕組みを可視化したもの) | 入力・実行するものではない。読んで仕組みを理解する |
| 言語名がないコードブロック | 実行結果・エラーメッセージ・ファイル構成などの「見本」 | 入力するものではない。自分の画面と見比べる |

### その他の記法

- **太字**:初めて出てくる専門用語や、特に注意してほしい箇所
- `>` で始まる引用(blockquote):補足説明・たとえ話・注意点・「やってみよう」という追加の実験
- `- [ ]`(チェックボックス):確認課題。自分で実装できたらチェックを付ける(手元のメモやIssueで管理してもよい)
- `[sample/xxx](sample/xxx)` のようなリンク:そのフェーズの完成例。詰まったときや答え合わせのときだけ見る(最初から見ないこと)

## フェーズ一覧

| フェーズ | テーマ | きっかけになる困りごと | 成果物 | 動く場所 |
| --- | --- | --- | --- | --- |
| [0](phases/phase-00-setup/README.md) | 開発準備とWebの仕組み | そもそもWebはどう動く? | 開発環境 | ― |
| [1](phases/phase-01-html-css-git/README.md) | HTML/CSS・Git基礎 | 自分のページを人に見せたい | 自己紹介ページ | GitHub Pages【デプロイ①】 |
| [2](phases/phase-02-python/README.md) | Python基礎 | 毎回同じ内容しか表示できない | CLI版Todo | ローカル |
| [3](phases/phase-03-flask/README.md) | Flask | ブラウザから操作したい | Web版Todo(メモリ保存) | localhost |
| [4](phases/phase-04-database/README.md) | データベース | 再起動するとデータが消える | DB版Todo | localhost |
| [5](phases/phase-05-auth/README.md) | 認証・認可 | 他人のTodoが見えてしまう | ログイン付きTodo | localhost |
| [6](phases/phase-06-vm-deploy/README.md) | 仮想サーバー | 自分のPCでしか動かない | 公開されたTodo | EC2【デプロイ②】 |
| [7](phases/phase-07-testing/README.md) | テスト・チーム開発 | 修正したら別の所が壊れた | テストコード・PR | EC2 |
| [8](phases/phase-08-api/README.md) | API化 | 画面とロジックが絡み合って変更しづらい | REST API + JSフロント | localhost |
| [9](phases/phase-09-docker/README.md) | Docker | 環境構築が毎回大変・PCごとに動作が違う | コンテナ化したアプリ | localhost |
| [10](phases/phase-10-ci/README.md) | CI | テストの実行を忘れる | 自動テスト | GitHub Actions |
| [11](phases/phase-11-cloud/README.md) | クラウド | VMの管理が大変 | クラウド上のアプリ | Lambda + API Gateway【デプロイ③】 |
| [12](phases/phase-12-cd/README.md) | CD | 手動デプロイが怖い・面倒 | 自動デプロイ | GitHub Actions → Lambda |

基本の学習はフェーズ0〜12で完了です。以下は、さらに深く学びたい人向けの **発展フェーズ(任意)** です。

| フェーズ | テーマ | 内容 |
| --- | --- | --- |
| [13](phases/phase-13-ecs-fargate/README.md) | ECS Fargate | フェーズ11のLambdaを、常駐型のECS Fargate + ALBに置き換え、本格的なVPC(パブリック/プライベートサブネット分離)を組み立てる |
| [14](phases/phase-14-cognito/README.md) | Cognito | フェーズ8のAPIの認証を、Flask-Login(セッションCookie)からAmazon Cognito(JWTトークン)に置き換える。本編のフェーズ5〜12は変更しない独立したサンプル |

## 使用技術

| 分類 | 技術 |
| --- | --- |
| 言語 | HTML / CSS / Python 3.12 / JavaScript |
| パッケージ管理 | uv |
| Webフレームワーク | Flask 3 |
| データベース | SQLite(フェーズ4〜8)→ PostgreSQL(フェーズ9〜) |
| テスト・品質 | pytest / pytest-cov / ruff |
| バージョン管理 | Git / GitHub |
| コンテナ | Docker / Docker Compose |
| CI/CD | GitHub Actions |
| クラウド | AWS(EC2 / Lambda / API Gateway / RDS / ECR / Secrets Manager) |

> クラウドは AWS を主軸に記載しています。Google Cloud で実施する場合の対応サービスは各フェーズのREADMEに併記しています。

## リポジトリ構成

```
.
├── README.md                 … このファイル
├── docs/
│   ├── template.md           … フェーズ教材を書くためのテンプレート(執筆者向け)
│   └── common-notes.md       … 全フェーズ共通の注意点(課金・秘密情報・つまずき対策)
└── phases/
    ├── phase-00-setup/
    │   └── README.md         … 教材本文
    ├── phase-01-html-css-git/
    │   ├── README.md
    │   └── sample/           … そのフェーズのハンズオン完了時点のコード
    └── ...
```

各フェーズの `sample/` には、**そのフェーズのハンズオンを終えた時点の完成コード** が入っています(確認課題の解答例は含みません)。
途中で詰まった場合は `sample/` を自分のリポジトリにコピーすれば、次のフェーズから再開できます。

> フェーズ10〜12の `sample/.github/workflows/` は参考用です。GitHub Actions はリポジトリのルート直下にあるワークフローしか実行しないため、この教材リポジトリ上では動きません。

## 学習者の進め方

1. 自分のGitHubアカウントで、学習用のリポジトリ(例:`my-todo-app`)を作成します
2. フェーズ0から順に、各フェーズの `README.md` を読みながら **自分のリポジトリで** 手を動かします
3. `sample/` は答え合わせや、詰まったときの参考にのみ使います(最初からコピーしないこと)
4. 各フェーズ最後の「振り返り」は、自分の言葉で書き出してから次へ進みます

学習を始める前に、必ず [全フェーズ共通の注意点](docs/common-notes.md) を読んでください。

## 学習環境

この教材は **Mac(macOS)** での学習を前提にしています。

- macOS(Apple シリコン / Intel のどちらでも可)
- ターミナル(zsh)、Homebrew
- Python 3.12、uv、Git、GitHub CLI
- Visual Studio Code、Google Chrome
- Docker Desktop for Mac(フェーズ9以降)

セットアップ手順は [フェーズ0](phases/phase-00-setup/README.md) にまとめています。
