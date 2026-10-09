#!/usr/bin/env bash
# =============================================================
# フェーズ12:GitHub Actions から AWS へ、アクセスキーなしで認証する設定
#            (IAM IDプロバイダ連携 / OIDC)
#
# README の Step に合わせて、ブロックごとにコピーして実行してください。
# 事前に commands.sh の「0. 変数の設定」を実行しておくこと。
# =============================================================

# ---------- 0. 追加の変数 ----------
export GITHUB_REPO="あなたのユーザー名/my-todo-app"   # owner/repo の形式
export DEPLOY_ROLE="github-deployer"

# ---------- 1. GitHub用のIDプロバイダを登録する(アカウントに1つだけでよい) ----------
# すでに他のリポジトリ用に作成済みの場合はスキップしてよい
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

export OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

# ---------- 2. デプロイ用ロールを作り、「自分のリポジトリのmainブランチから」だけを信頼する ----------
cat > /tmp/github-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "${OIDC_PROVIDER_ARN}"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
      "StringLike": {"token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:ref:refs/heads/main"}
    }
  }]
}
EOF

aws iam create-role --role-name "$DEPLOY_ROLE" --assume-role-policy-document file:///tmp/github-trust-policy.json

# ---------- 3. 必要な権限だけを付ける ----------
# イメージをECRにpushする権限
cat > /tmp/ecr-push-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*"},
    {
      "Effect": "Allow",
      "Action": ["ecr:BatchCheckLayerAvailability", "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"],
      "Resource": "arn:aws:ecr:${AWS_REGION}:${ACCOUNT_ID}:repository/${REPO}"
    }
  ]
}
EOF
aws iam put-role-policy --role-name "$DEPLOY_ROLE" --policy-name todo-ecr-push --policy-document file:///tmp/ecr-push-policy.json

# Lambdaの関数コードを更新する権限(この関数だけに限定)
cat > /tmp/lambda-deploy-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["lambda:UpdateFunctionCode", "lambda:GetFunction"],
    "Resource": "arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${FUNCTION}"
  }]
}
EOF
aws iam put-role-policy --role-name "$DEPLOY_ROLE" --policy-name todo-lambda-deploy --policy-document file:///tmp/lambda-deploy-policy.json

export DEPLOY_ROLE_ARN="$(aws iam get-role --role-name "$DEPLOY_ROLE" --query Role.Arn --output text)"

# ---------- 4. GitHubに登録する値を表示する ----------
echo "AWS_REGION     = ${AWS_REGION}"
echo "AWS_ACCOUNT_ID = ${ACCOUNT_ID}"
echo "AWS_ROLE_ARN   = ${DEPLOY_ROLE_ARN}"

# ---------- 後片付け(学習が終わったら commands.sh の後片付けと一緒に実行)----------
# aws iam delete-role-policy --role-name "$DEPLOY_ROLE" --policy-name todo-ecr-push
# aws iam delete-role-policy --role-name "$DEPLOY_ROLE" --policy-name todo-lambda-deploy
# aws iam delete-role --role-name "$DEPLOY_ROLE"
# IDプロバイダは他のリポジトリでも使い回せるため、通常は削除不要
