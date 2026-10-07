# CLAUDE.md

このファイルは、このリポジトリで作業する Claude Code (claude.ai/code) に向けたガイドです。

## このリポジトリについて

このリポジトリは**アプリケーションそのものではありません**。プログラミング未経験者向けに、Todoアプリを13フェーズかけて育てながら「作る → テストする → コンテナ化する → クラウドにデプロイする」までを学ぶ、日本語の教材リポジトリです。このリポジトリの成果物は `phases/*/README.md` 配下の教材本文(Markdown)であり、各 `phases/*/sample/` ディレクトリのコードは「そのフェーズを終えた時点の参考実装(完成例)」であって、単一の実行可能アプリケーションではありません。

各フェーズは前フェーズの続きとして書かれています。学習者は**自分自身の別リポジトリ**(例: `my-todo-app`)でフェーズ0から順に手を動かす想定であり、このリポジトリの `sample/` はあくまで答え合わせ・詰まったときの再開用スナップショットです。このリポジトリ自体を1つのモノレポとして `cd` して通しで動かす対象ではありません。

## リポジトリ構成

```
README.md                      … 教材全体の概要(フェーズ一覧表・使用技術・リポジトリ構成の説明)
docs/
  template.md                  … 各フェーズREADMEの執筆テンプレート(構成と執筆ルール)
  common-notes.md               … 全フェーズ共通の注意点(課金事故防止・秘密情報管理・つまずき対策)。フェーズ本文を書く/レビューする前に必ず参照する
phases/
  phase-00-setup/README.md      … sample/ なし(環境構築のみ)
  phase-01-html-css-git/{README.md,sample/}
  phase-02-python/{README.md,sample/}
  ...
  phase-12-cd/{README.md,sample/}
```

フェーズのテーマ(詳細な表はルートの `README.md` を参照):
0 開発準備 → 1 HTML/CSS/Git(→ GitHub Pages)→ 2 Python基礎(CLI)→ 3 Flask(メモリ保存)→ 4 データベース(SQLite)→ 5 認証・認可 → 6 仮想サーバー(→ 手動デプロイ)→ 7 テスト・チーム開発 → 8 API化(REST + JSフロント)→ 9 Docker → 10 CI(GitHub Actions)→ 11 クラウド(Cloud Run)→ 12 CD(自動デプロイ)。

`sample/` のコードは累積的に発展していきます。フェーズ7以降は、単一の `app.py` から `todo_app/` パッケージ構成(`__init__.py`、`auth.py`、`todos.py`、フェーズ8からは `api.py`、`models.py`、`extensions.py`、`wsgi.py`)へ再構成され、`tests/`・`pyproject.toml`(pytest / ruff 設定)・`requirements-dev.txt`・`docs/api.md` / `docs/testcases.md` が追加されます。フェーズ9以降は `Dockerfile` / `compose.yaml`、フェーズ10以降は `.github/workflows/`、フェーズ11以降は `deploy/gcp/` が追加されます。

**注意**: `phases/phase-10-ci/sample/` 以降の `.github/workflows/` は参考用です。GitHub Actions はリポジトリの**ルート直下**にあるワークフローしか実行しないため、この教材リポジトリ上では意図的に動作しません。

## このリポジトリでの作業

ルート直下には共通のビルド/lint/testコマンドはありません(単一の実行対象アプリが存在しないため)。特定フェーズの `sample/` を検証する場合は、そのフェーズの `sample/` ディレクトリに入って作業します。フェーズ7以降は標準的なFlaskプロジェクト構成です。

```bash
cd phases/phase-0N-xxx/sample
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt   # requirements-dev.txt はフェーズ7以降
pytest                                                     # テスト実行(pyproject.toml の testpaths = tests)
ruff check .                                               # lint(フェーズ12のpyproject.toml基準: E,W,F,I,B / line-length 100 / py312)
```

教材全体で使う技術スタック(正式な一覧はルートの `README.md` 参照): Python 3.12、Flask 3、SQLite → PostgreSQL(フェーズ9〜)、pytest / pytest-cov / ruff、Docker / Docker Compose、GitHub Actions、Google Cloud(Compute Engine / Cloud Run / Cloud SQL / Artifact Registry)。AWSで実施する場合の対応サービスは該当フェーズのREADMEに併記されています。

## フェーズ教材を編集・追加するときのルール

各フェーズの `README.md` は `docs/template.md` で定義された固定の5部構成に従います。教材本文を編集する際はこの構成から逸脱しないこと。

1. **なぜ学ぶか** — 必ず**前フェーズで起きた困りごと**から書き始め、このフェーズの技術がそれをどう解決するかにつなげる。
2. **仕組みの解説** — 概念の説明。可能な限りMermaid図を使う。
3. **ハンズオン** — 各ステップは「コマンド」と「**期待される結果**」を必ずセットで書く(コマンドだけを書かない)。
4. **確認課題** — 手順は書かず、**ゴールのみ**を示す。
5. **振り返り** — 締めの問い。最後の問いは必ず**次フェーズの「なぜ学ぶか」につながる**ものにする。

各フェーズのREADMEの末尾には、`sample/` のファイル構成の説明と「よくあるエラー」表も置く。

`docs/common-notes.md` とルートの `README.md` に由来する、その他の厳守事項:
- 読者は**macOS前提の未経験者**(zsh、Homebrew、`command` と `control` キーの違いが重要)。Linux/Windows前提の手順を書かないこと。
- Flaskの開発サーバーはポート`5000`ではなく**`5001`**を使う(macOSのAirPlayレシーバーが5000番を使用しているため)。phase-00/03本文および `common-notes.md` で明示されているルール。
- `.env`・APIキー・`SECRET_KEY` など秘密情報を扱う内容を追加する場合は、`common-notes.md` の秘密情報管理ルールに従い、`.env.example` と `.gitignore` によるカバーを必ずセットで用意する。
- クラウドリソースを扱う内容(フェーズ6・11・12)を追加・変更する場合は、課金事故防止のため「後片付け」手順を必ず含め、`common-notes.md` の予算アラートの案内にも触れる。
- 1文を短くし、専門用語は初出時に一言で説明する(テンプレートの執筆ルールに明記)。

`sample/` を変更してREADMEの内容と整合させる場合は、それ以降のフェーズとの整合性にも注意すること(例: phase-07の `todo_app/models.py` を変更したら、phase-08〜12の同名ファイルは同じアプリの累積的な派生なので、通常は同じ変更を反映する必要がある)。
