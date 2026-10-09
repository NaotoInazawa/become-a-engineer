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

# ===== Lambda Web Adapter(フェーズ11)=====
# Lambda上でこのコンテナを「普通のWebサーバー」として動かすための変換アダプター。
# ローカルやDocker Composeで動かす分にはこの2行がなくても無視されるだけで、影響はない。
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 /lambda-adapter /opt/extensions/lambda-adapter
ENV AWS_LWA_PORT=8000

# このコンテナが待ち受けるポート(ドキュメント的な意味)
EXPOSE 8000

# ===== 起動コマンド =====
# コンテナの外(ホストPC)から接続できるよう、0.0.0.0 で待ち受ける。
CMD ["gunicorn", "--workers", "1", "--threads", "4", "--bind", "0.0.0.0:8000", "wsgi:app"]
