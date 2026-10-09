"""データベースのモデル(テーブル定義)

Cognitoがユーザー管理を担うため、フェーズ5〜8にあった User テーブルは不要になる。
代わりに、Todoが「どのCognitoユーザーのものか」を cognito_sub(Cognitoが発行する
ユーザーごとに一意なID)で記録する。
"""

from datetime import datetime

from .extensions import db


class Todo(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    done = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.now)
    # Cognitoのユーザー識別子(JWTの"sub"クレームの値)。ローカルにUserテーブルを持たない
    cognito_sub = db.Column(db.String(64), nullable=False, index=True)
