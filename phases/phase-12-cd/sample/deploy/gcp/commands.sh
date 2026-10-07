#!/usr/bin/env bash
# =============================================================
# フェーズ11:Cloud Run へのデプロイ手順(Google Cloud)
#
# このファイルは「一気に実行するスクリプト」ではありません。
# README の Step に合わせて、ブロックごとにコピーして実行し、
# 結果を確認しながら進めてください。
# =============================================================

# ---------- 0. 変数の設定(ターミナルを開き直したら毎回実行) ----------
export PROJECT_ID="your-project-id"          # GCPのプロジェクトID
export REGION="asia-northeast1"              # 東京リージョン
export REPO="todo"                           # Artifact Registry のリポジトリ名
export SERVICE="todo"                        # Cloud Run のサービス名
export SQL_INSTANCE="todo-db"                # Cloud SQL のインスタンス名
export SA_NAME="todo-run"                    # Cloud Run 用のサービスアカウント名
export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
export IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/web"

# ---------- 1. gcloud の初期設定 ----------
gcloud auth login
gcloud config set project "$PROJECT_ID"
gcloud config set run/region "$REGION"

# 使うサービス(API)を有効にする
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com

# ---------- 2. Artifact Registry(イメージの置き場所)----------
gcloud artifacts repositories create "$REPO" \
  --repository-format=docker \
  --location="$REGION"

# docker push のときに GCP の認証を使うよう設定する
gcloud auth configure-docker "${REGION}-docker.pkg.dev"

# イメージをビルドして push する
# (Apple Silicon の Mac でも動くように linux/amd64 を指定する)
docker build --platform linux/amd64 -t "${IMAGE}:v1" .
docker push "${IMAGE}:v1"

# ---------- 3. Cloud SQL(マネージドDB)----------
# ※ Cloud SQL は無料枠がありません。学習が終わったら必ず削除してください(後片付け参照)
gcloud sql instances create "$SQL_INSTANCE" \
  --database-version=POSTGRES_16 \
  --edition=enterprise \
  --tier=db-f1-micro \
  --region="$REGION"

gcloud sql databases create todo --instance="$SQL_INSTANCE"

# DBユーザーのパスワードを生成して作成する
export DB_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
gcloud sql users create todo --instance="$SQL_INSTANCE" --password="$DB_PASSWORD"

# Cloud Run からは Unix ソケット経由で接続する
export CONNECTION_NAME="$(gcloud sql instances describe "$SQL_INSTANCE" --format='value(connectionName)')"
export DATABASE_URL="postgresql+psycopg://todo:${DB_PASSWORD}@/todo?host=/cloudsql/${CONNECTION_NAME}"

# ---------- 4. Secret Manager(秘密情報)----------
python3 -c 'import secrets; print(secrets.token_hex(32), end="")' \
  | gcloud secrets create todo-secret-key --data-file=-
printf '%s' "$DATABASE_URL" \
  | gcloud secrets create todo-database-url --data-file=-

# ---------- 5. サービスアカウント(最小権限)----------
gcloud iam service-accounts create "$SA_NAME" --display-name="Todo Cloud Run"

# Cloud SQL に接続する権限
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" --role="roles/cloudsql.client"

# 2つのシークレットを読む権限(シークレット単位で付与する)
for SECRET in todo-secret-key todo-database-url; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:${SA_EMAIL}" --role="roles/secretmanager.secretAccessor"
done

# ---------- 6. Cloud Run にデプロイ ----------
gcloud run deploy "$SERVICE" \
  --image="${IMAGE}:v1" \
  --service-account="$SA_EMAIL" \
  --add-cloudsql-instances="$CONNECTION_NAME" \
  --set-secrets="SECRET_KEY=todo-secret-key:latest,DATABASE_URL=todo-database-url:latest" \
  --allow-unauthenticated \
  --max-instances=2

# 発行された URL を確認する
gcloud run services describe "$SERVICE" --format='value(status.url)'

# ---------- 7. ログ・リビジョン ----------
gcloud run services logs read "$SERVICE" --limit=50
gcloud run revisions list --service="$SERVICE"

# 前のリビジョンにすべてのトラフィックを戻す(ロールバック)
# gcloud run services update-traffic "$SERVICE" --to-revisions=リビジョン名=100

# ---------- 8. 後片付け(学習が終わったら必ず実行)----------
# gcloud run services delete "$SERVICE"
# gcloud sql instances delete "$SQL_INSTANCE"
# gcloud artifacts repositories delete "$REPO" --location="$REGION"
# gcloud secrets delete todo-secret-key
# gcloud secrets delete todo-database-url
# gcloud iam service-accounts delete "$SA_EMAIL"
