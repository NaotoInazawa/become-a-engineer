# ===== ベースイメージ =====
# Python 3.12 が入った軽量な Linux(Debian)から始める
FROM python:3.12-slim

# Python の出力をバッファせずにすぐ表示する(ログが遅れないように)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# コンテナ内の作業フォルダ
WORKDIR /app

# ===== ライブラリのインストール =====
# requirements.txt だけを先にコピーしてインストールする。
# コードだけを変更したときは、このステップのキャッシュが再利用されてビルドが速くなる
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ===== アプリのコードをコピー =====
COPY . .

# 管理者(root)ではなく、一般ユーザーでアプリを動かす(安全のため)
RUN useradd --create-home appuser && chown -R appuser /app
USER appuser

# ECS Fargateでは、コンテナをそのまま動かすのでLambda Web Adapterは不要
# (フェーズ11はLambda専用の変換アダプターが必要だったが、ECSは「普通のコンテナ」として扱う)

# このコンテナが待ち受けるポート(ドキュメント的な意味)
EXPOSE 8000

# ===== 起動コマンド =====
# コンテナの外(ホストPC)から接続できるよう、0.0.0.0 で待ち受ける。
CMD ["gunicorn", "--workers", "1", "--threads", "4", "--bind", "0.0.0.0:8000", "wsgi:app"]
