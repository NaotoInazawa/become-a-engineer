#!/usr/bin/env bash
# =============================================================
# フェーズ13(発展):ECS Fargate へのデプロイ手順(AWS)
#
# このファイルは「一気に実行するスクリプト」ではありません。
# README の Step に合わせて、ブロックごとにコピーして実行し、
# 結果を確認しながら進めてください。
# =============================================================

# ---------- 0. 変数の設定(ターミナルを開き直したら毎回実行) ----------
export AWS_REGION="ap-northeast-1"
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export REPO="todo"
export CLUSTER="todo-cluster"
export SERVICE="todo-service"
export DB_INSTANCE="todo-db"
export IMAGE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO}"

# ---------- 1. イメージをビルドしてECRにpushする(Lambda Web Adapterなし版) ----------
aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION" 2>/dev/null || true
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
docker build --platform linux/amd64 -t "${IMAGE}:v1" .
docker push "${IMAGE}:v1"

# ---------- 2. VPC(パブリック/プライベートサブネットを分離)----------
export VPC_ID="$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text)"
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=todo-vpc

# パブリックサブネット(ALB・NAT Gateway用)
export PUB_SUBNET_A="$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 --availability-zone "${AWS_REGION}a" --query Subnet.SubnetId --output text)"
export PUB_SUBNET_C="$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 --availability-zone "${AWS_REGION}c" --query Subnet.SubnetId --output text)"

# プライベートサブネット(ECSタスク・RDS用。インターネットから直接到達できない)
export PRIV_SUBNET_A="$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.11.0/24 --availability-zone "${AWS_REGION}a" --query Subnet.SubnetId --output text)"
export PRIV_SUBNET_C="$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.12.0/24 --availability-zone "${AWS_REGION}c" --query Subnet.SubnetId --output text)"

# インターネットゲートウェイ(パブリックサブネットの出入り口)
export IGW_ID="$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)"
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"

export PUB_RT_ID="$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query RouteTable.RouteTableId --output text)"
aws ec2 create-route --route-table-id "$PUB_RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$PUB_RT_ID" --subnet-id "$PUB_SUBNET_A"
aws ec2 associate-route-table --route-table-id "$PUB_RT_ID" --subnet-id "$PUB_SUBNET_C"
aws ec2 modify-subnet-attribute --subnet-id "$PUB_SUBNET_A" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$PUB_SUBNET_C" --map-public-ip-on-launch

# NAT Gateway(プライベートサブネットから外部へ出るときの出口。課金されるので後片付け必須)
export EIP_ALLOC="$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)"
export NAT_GW_ID="$(aws ec2 create-nat-gateway --subnet-id "$PUB_SUBNET_A" --allocation-id "$EIP_ALLOC" --query NatGateway.NatGatewayId --output text)"
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW_ID"

export PRIV_RT_ID="$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query RouteTable.RouteTableId --output text)"
aws ec2 create-route --route-table-id "$PRIV_RT_ID" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID"
aws ec2 associate-route-table --route-table-id "$PRIV_RT_ID" --subnet-id "$PRIV_SUBNET_A"
aws ec2 associate-route-table --route-table-id "$PRIV_RT_ID" --subnet-id "$PRIV_SUBNET_C"

# ---------- 3. セキュリティグループ(ALB → ECS → RDS の一方向だけを許可)----------
export ALB_SG="$(aws ec2 create-security-group --group-name todo-alb-sg --description "ALB" --vpc-id "$VPC_ID" --query GroupId --output text)"
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 80 --cidr 0.0.0.0/0

export ECS_SG="$(aws ec2 create-security-group --group-name todo-ecs-sg --description "ECS tasks" --vpc-id "$VPC_ID" --query GroupId --output text)"
aws ec2 authorize-security-group-ingress --group-id "$ECS_SG" --protocol tcp --port 8000 --source-group "$ALB_SG"

export DB_SG="$(aws ec2 create-security-group --group-name todo-db-sg --description "RDS" --vpc-id "$VPC_ID" --query GroupId --output text)"
aws ec2 authorize-security-group-ingress --group-id "$DB_SG" --protocol tcp --port 5432 --source-group "$ECS_SG"

# ---------- 4. RDS(プライベートサブネットに作成。パブリックアクセス不可)----------
aws rds create-db-subnet-group \
  --db-subnet-group-name todo-db-subnets \
  --db-subnet-group-description "private subnets" \
  --subnet-ids "$PRIV_SUBNET_A" "$PRIV_SUBNET_C"

export DB_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE" \
  --db-instance-class db.t3.micro \
  --engine postgres --engine-version 16.4 \
  --master-username todo --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --db-subnet-group-name todo-db-subnets \
  --vpc-security-group-ids "$DB_SG" \
  --no-multi-az --no-publicly-accessible

aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE"
export DB_HOST="$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE" --query 'DBInstances[0].Endpoint.Address' --output text)"
export DATABASE_URL="postgresql+psycopg://todo:${DB_PASSWORD}@${DB_HOST}:5432/postgres"

# ---------- 5. Secrets Manager ----------
python3 -c 'import secrets; print(secrets.token_hex(32), end="")' \
  | aws secretsmanager create-secret --name todo-secret-key --secret-string file:///dev/stdin
printf '%s' "$DATABASE_URL" \
  | aws secretsmanager create-secret --name todo-database-url --secret-string file:///dev/stdin
export SECRET_KEY_ARN="$(aws secretsmanager describe-secret --secret-id todo-secret-key --query ARN --output text)"
export DATABASE_URL_ARN="$(aws secretsmanager describe-secret --secret-id todo-database-url --query ARN --output text)"

# ---------- 6. ECSクラスター・ロール ----------
aws ecs create-cluster --cluster-name "$CLUSTER"

# タスク実行ロール(ECRからのpull、ログ書き込み、Secrets Managerの読み取り)
cat > /tmp/ecs-trust-policy.json <<'EOF'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}
EOF
aws iam create-role --role-name todo-ecs-execution --assume-role-policy-document file:///tmp/ecs-trust-policy.json
aws iam attach-role-policy --role-name todo-ecs-execution --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

cat > /tmp/ecs-secrets-policy.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"secretsmanager:GetSecretValue","Resource":["${SECRET_KEY_ARN}","${DATABASE_URL_ARN}"]}]}
EOF
aws iam put-role-policy --role-name todo-ecs-execution --policy-name todo-secrets-access --policy-document file:///tmp/ecs-secrets-policy.json
export EXEC_ROLE_ARN="$(aws iam get-role --role-name todo-ecs-execution --query Role.Arn --output text)"

aws logs create-log-group --log-group-name /ecs/todo 2>/dev/null || true

# ---------- 7. タスク定義 ----------
cat > /tmp/task-def.json <<EOF
{
  "family": "todo",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "${EXEC_ROLE_ARN}",
  "containerDefinitions": [{
    "name": "todo",
    "image": "${IMAGE}:v1",
    "portMappings": [{"containerPort": 8000}],
    "secrets": [
      {"name": "SECRET_KEY_ARN", "valueFrom": "${SECRET_KEY_ARN}"},
      {"name": "DATABASE_URL_ARN", "valueFrom": "${DATABASE_URL_ARN}"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/todo",
        "awslogs-region": "${AWS_REGION}",
        "awslogs-stream-prefix": "todo"
      }
    }
  }]
}
EOF
aws ecs register-task-definition --cli-input-json file:///tmp/task-def.json

# ---------- 8. ALB(ロードバランサー)----------
export ALB_ARN="$(aws elbv2 create-load-balancer --name todo-alb --subnets "$PUB_SUBNET_A" "$PUB_SUBNET_C" --security-groups "$ALB_SG" --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
export TG_ARN="$(aws elbv2 create-target-group --name todo-tg --protocol HTTP --port 8000 --vpc-id "$VPC_ID" --target-type ip --health-check-path /health --query 'TargetGroups[0].TargetGroupArn' --output text)"
aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 --default-actions "Type=forward,TargetGroupArn=${TG_ARN}"

# ---------- 9. ECSサービス(タスクを指定数、動かし続ける)----------
aws ecs create-service \
  --cluster "$CLUSTER" \
  --service-name "$SERVICE" \
  --task-definition todo \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${PRIV_SUBNET_A},${PRIV_SUBNET_C}],securityGroups=[${ECS_SG}],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=${TG_ARN},containerName=todo,containerPort=8000"

aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"

# 発行されたURLを確認する
aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text

# ---------- 10. 自動スケーリング(任意)----------
aws application-autoscaling register-scalable-target \
  --service-namespace ecs --resource-id "service/${CLUSTER}/${SERVICE}" \
  --scalable-dimension ecs:service:DesiredCount --min-capacity 2 --max-capacity 5

cat > /tmp/scaling-policy.json <<'EOF'
{
  "TargetValue": 60.0,
  "PredefinedMetricSpecification": {"PredefinedMetricType": "ECSServiceAverageCPUUtilization"}
}
EOF
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs --resource-id "service/${CLUSTER}/${SERVICE}" \
  --scalable-dimension ecs:service:DesiredCount --policy-name todo-cpu-scaling \
  --policy-type TargetTrackingScaling --target-tracking-scaling-policy-configuration file:///tmp/scaling-policy.json

# ---------- 11. 後片付け(学習が終わったら必ず実行。特にNAT Gatewayは時間課金されます)----------
# aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --desired-count 0
# aws ecs delete-service --cluster "$CLUSTER" --service "$SERVICE" --force
# aws elbv2 delete-listener --listener-arn (describe-listenersで確認)
# aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
# aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
# aws ecs delete-cluster --cluster "$CLUSTER"
# aws rds delete-db-instance --db-instance-identifier "$DB_INSTANCE" --skip-final-snapshot
# aws rds delete-db-subnet-group --db-subnet-group-name todo-db-subnets
# aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW_ID"   # 削除完了まで数分待ってから次へ
# aws ec2 release-address --allocation-id "$EIP_ALLOC"
# aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
# aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
# (ルートテーブル・サブネット・セキュリティグループ・VPC本体もこの後に削除)
