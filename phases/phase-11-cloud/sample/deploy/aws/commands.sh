#!/usr/bin/env bash
# =============================================================
# フェーズ11:Lambda + API Gateway へのデプロイ手順(AWS)
#
# このファイルは「一気に実行するスクリプト」ではありません。
# README の Step に合わせて、ブロックごとにコピーして実行し、
# 結果を確認しながら進めてください。
# =============================================================

# ---------- 0. 変数の設定(ターミナルを開き直したら毎回実行) ----------
export AWS_REGION="ap-northeast-1"            # 東京リージョン
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export REPO="todo"                            # ECR リポジトリ名
export FUNCTION="todo"                        # Lambda 関数名
export API_NAME="todo-api"                    # API Gateway の名前
export DB_INSTANCE="todo-db"                  # RDS インスタンス名
export EXEC_ROLE="todo-lambda-execution"      # Lambda 実行ロール名
export IMAGE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO}"

# ---------- 1. ECR にイメージを push する ----------
aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION" 2>/dev/null || true

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# (Apple Silicon の Mac でも x86_64 の Lambda で動くように linux/amd64 を指定する)
docker build --platform linux/amd64 -t "${IMAGE}:v1" .
docker push "${IMAGE}:v1"

# ---------- 2. RDS(マネージドDB)----------
# デフォルトVPC・デフォルトのセキュリティグループを使う、最小構成の例です。
export DEFAULT_VPC="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)"
export DB_SG="$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$DEFAULT_VPC Name=group-name,Values=default --query 'SecurityGroups[0].GroupId' --output text)"

export DB_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"

# ※ RDSは無料利用枠の対象外のアカウントでは起動時間に応じて課金されます(Step 0 参照)
aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE" \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16.4 \
  --master-username todo \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --vpc-security-group-ids "$DB_SG" \
  --no-multi-az \
  --no-publicly-accessible

# 作成完了まで数分待つ
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE"
export DB_HOST="$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" --query 'DBInstances[0].Endpoint.Address' --output text)"
export DATABASE_URL="postgresql+psycopg://todo:${DB_PASSWORD}@${DB_HOST}:5432/postgres"

# ---------- 3. Secrets Manager(秘密情報)----------
python3 -c 'import secrets; print(secrets.token_hex(32), end="")' \
  | aws secretsmanager create-secret --name todo-secret-key --secret-string file:///dev/stdin
printf '%s' "$DATABASE_URL" \
  | aws secretsmanager create-secret --name todo-database-url --secret-string file:///dev/stdin

export SECRET_KEY_ARN="$(aws secretsmanager describe-secret --secret-id todo-secret-key --query ARN --output text)"
export DATABASE_URL_ARN="$(aws secretsmanager describe-secret --secret-id todo-database-url --query ARN --output text)"

# ---------- 4. 実行ロール(最小権限)----------
cat > /tmp/trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name "$EXEC_ROLE" --assume-role-policy-document file:///tmp/trust-policy.json

# RDSに接続するため、LambdaをVPCの中で動かす権限(AWSマネージドポリシー)
aws iam attach-role-policy --role-name "$EXEC_ROLE" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole

# 2つのシークレットだけを読む権限(シークレット単位で絞る)
cat > /tmp/secrets-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "secretsmanager:GetSecretValue",
    "Resource": ["${SECRET_KEY_ARN}", "${DATABASE_URL_ARN}"]
  }]
}
EOF
aws iam put-role-policy --role-name "$EXEC_ROLE" --policy-name todo-secrets-access --policy-document file:///tmp/secrets-policy.json

export EXEC_ROLE_ARN="$(aws iam get-role --role-name "$EXEC_ROLE" --query Role.Arn --output text)"

# ---------- 5. Lambda 関数を作る(VPCに接続) ----------
export LAMBDA_SG="$DB_SG"
export SUBNETS="$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$DEFAULT_VPC --query 'Subnets[].SubnetId' --output text | tr '\t' ',')"

aws lambda create-function \
  --function-name "$FUNCTION" \
  --package-type Image \
  --code ImageUri="${IMAGE}:v1" \
  --role "$EXEC_ROLE_ARN" \
  --timeout 30 \
  --memory-size 512 \
  --architectures x86_64 \
  --vpc-config "SubnetIds=${SUBNETS},SecurityGroupIds=${LAMBDA_SG}" \
  --environment "Variables={SECRET_KEY_ARN=${SECRET_KEY_ARN},DATABASE_URL_ARN=${DATABASE_URL_ARN}}"

aws lambda wait function-active --function-name "$FUNCTION"

# ---------- 6. API Gateway を作り、Lambdaと繋ぐ ----------
export API_ID="$(aws apigatewayv2 create-api \
  --name "$API_NAME" \
  --protocol-type HTTP \
  --target "arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${FUNCTION}" \
  --query ApiId --output text)"

# API Gateway から Lambda を呼び出す権限
aws lambda add-permission \
  --function-name "$FUNCTION" \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${ACCOUNT_ID}:${API_ID}/*/*"

# 発行された URL を確認する
aws apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiEndpoint" --output text

# ---------- 7. ログ ----------
aws logs tail "/aws/lambda/${FUNCTION}" --since 10m

# ---------- 8. 後片付け(学習が終わったら必ず実行)----------
# aws apigatewayv2 delete-api --api-id "$API_ID"
# aws lambda delete-function --function-name "$FUNCTION"
# aws rds delete-db-instance --db-instance-identifier "$DB_INSTANCE" --skip-final-snapshot
# aws secretsmanager delete-secret --secret-id todo-secret-key --force-delete-without-recovery
# aws secretsmanager delete-secret --secret-id todo-database-url --force-delete-without-recovery
# aws iam delete-role-policy --role-name "$EXEC_ROLE" --policy-name todo-secrets-access
# aws iam detach-role-policy --role-name "$EXEC_ROLE" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
# aws iam delete-role --role-name "$EXEC_ROLE"
# aws ecr delete-repository --repository-name "$REPO" --force
