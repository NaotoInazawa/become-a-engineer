#!/usr/bin/env bash
# =============================================================
# フェーズ14(発展):Amazon Cognitoの構築手順
#
# このフェーズはローカル(Mac)でFlaskを動かしたまま、認証基盤だけを
# 本物のCognitoに向ける構成です。ブロックごとにコピーして実行してください。
# =============================================================

# ---------- 0. 変数の設定 ----------
export AWS_REGION="ap-northeast-1"
export POOL_NAME="todo-user-pool"
export APP_CLIENT_NAME="todo-app-client"

# ---------- 1. User Poolを作る ----------
export USER_POOL_ID="$(aws cognito-idp create-user-pool \
  --pool-name "$POOL_NAME" \
  --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":false,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":false}}' \
  --query 'UserPool.Id' --output text)"

# ---------- 2. App Client(このアプリ用のクライアント設定)を作る ----------
export APP_CLIENT_ID="$(aws cognito-idp create-user-pool-client \
  --user-pool-id "$USER_POOL_ID" \
  --client-name "$APP_CLIENT_NAME" \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --no-generate-secret \
  --query 'UserPoolClient.ClientId' --output text)"

echo "AWS_REGION            = ${AWS_REGION}"
echo "COGNITO_USER_POOL_ID   = ${USER_POOL_ID}"
echo "COGNITO_APP_CLIENT_ID  = ${APP_CLIENT_ID}"
# これらの値を .env にコピーする(.env.example を参考に)

# ---------- 3. テストユーザーを作る(確認メールを省略) ----------
export TEST_EMAIL="alice@example.com"
export TEST_PASSWORD="Passw0rd123"

aws cognito-idp admin-create-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_EMAIL" \
  --user-attributes Name=email,Value="$TEST_EMAIL" Name=email_verified,Value=true \
  --message-action SUPPRESS

# 一時パスワードではなく、すぐ使えるパスワードを設定する
aws cognito-idp admin-set-user-password \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_EMAIL" \
  --password "$TEST_PASSWORD" \
  --permanent

# ---------- 4. サインインしてトークンを取得する ----------
export ID_TOKEN="$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$APP_CLIENT_ID" \
  --auth-parameters USERNAME="$TEST_EMAIL",PASSWORD="$TEST_PASSWORD" \
  --query 'AuthenticationResult.IdToken' --output text)"

echo "$ID_TOKEN"   # これがJWT。ヘッダー.ペイロード.署名の3つがドットで繋がった長い文字列

# ---------- 5. ローカルで起動して、トークン付きでAPIを呼ぶ ----------
# 別のターミナルで `flask --app wsgi run --debug --port 5001` を起動してから:
#
# curl -H "Authorization: Bearer ${ID_TOKEN}" http://127.0.0.1:5001/api/todos
# curl -X POST -H "Authorization: Bearer ${ID_TOKEN}" -H "Content-Type: application/json" \
#      -d '{"title":"牛乳を買う"}' http://127.0.0.1:5001/api/todos

# ---------- 6. 後片付け(学習が終わったら必ず実行)----------
# aws cognito-idp delete-user-pool-client --user-pool-id "$USER_POOL_ID" --client-id "$APP_CLIENT_ID"
# aws cognito-idp delete-user-pool --user-pool-id "$USER_POOL_ID"
