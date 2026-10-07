#!/usr/bin/env bash
# =============================================================
# フェーズ12:GitHub Actions から GCP へ、アクセスキーなしで認証する設定
#            (Workload Identity 連携 / OIDC)
#
# README の Step に合わせて、ブロックごとにコピーして実行してください。
# 事前に commands.sh の「0. 変数の設定」を実行しておくこと。
# =============================================================

# ---------- 0. 追加の変数 ----------
export GITHUB_REPO="あなたのユーザー名/my-todo-app"   # owner/repo の形式
export PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
export DEPLOY_SA_NAME="github-deployer"
export DEPLOY_SA_EMAIL="${DEPLOY_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud services enable iamcredentials.googleapis.com

# ---------- 1. デプロイ用サービスアカウントを作り、必要な権限だけを付ける ----------
gcloud iam service-accounts create "$DEPLOY_SA_NAME" --display-name="GitHub Actions deployer"

# Cloud Run にデプロイする権限
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${DEPLOY_SA_EMAIL}" --role="roles/run.developer"

# イメージを Artifact Registry に push する権限(todo リポジトリだけ)
gcloud artifacts repositories add-iam-policy-binding "$REPO" \
  --location="$REGION" \
  --member="serviceAccount:${DEPLOY_SA_EMAIL}" --role="roles/artifactregistry.writer"

# Cloud Run を「todo-run サービスアカウント」として動かす権限
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --member="serviceAccount:${DEPLOY_SA_EMAIL}" --role="roles/iam.serviceAccountUser"

# ---------- 2. Workload Identity プールとプロバイダを作る ----------
gcloud iam workload-identity-pools create github \
  --location=global \
  --display-name="GitHub Actions"

# GitHub が発行するトークンを信頼する。
# attribute-condition で「自分のリポジトリからのトークンだけ」に限定する(重要)
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='${GITHUB_REPO}'"

# ---------- 3. 自分のリポジトリにだけ、デプロイ用サービスアカウントの利用を許可する ----------
gcloud iam service-accounts add-iam-policy-binding "$DEPLOY_SA_EMAIL" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/${GITHUB_REPO}"

# ---------- 4. GitHub に登録する値を表示する ----------
echo "GCP_PROJECT_ID   = ${PROJECT_ID}"
echo "GCP_REGION       = ${REGION}"
echo "GCP_WIF_PROVIDER = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/providers/github-provider"
echo "GCP_DEPLOY_SA    = ${DEPLOY_SA_EMAIL}"

# ---------- 5. 後片付け(学習が終わったら commands.sh の後片付けと一緒に実行)----------
# gcloud iam workload-identity-pools delete github --location=global
# gcloud iam service-accounts delete "$DEPLOY_SA_EMAIL"
