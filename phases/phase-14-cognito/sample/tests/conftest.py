"""テスト全体で使う準備(フィクスチャ)

本物のCognitoに問い合わせる代わりに、テスト用のRSA鍵ペアで自分自身の
JWTを発行し、todo_app.cognito_auth が参照する鍵取得処理をその場で
差し替える(モンキーパッチ)ことで、ネットワークに出ずに認証を再現する。
"""

import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from todo_app import create_app
from todo_app.extensions import db
import todo_app.cognito_auth as cognito_auth

TEST_ISSUER = "https://cognito-idp.ap-northeast-1.amazonaws.com/ap-northeast-1_TESTPOOL"
TEST_AUDIENCE = "test-app-client-id"

_private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)


class _FakeSigningKey:
    def __init__(self, key):
        self.key = key


class _FakeJWKClient:
    def get_signing_key_from_jwt(self, token):
        return _FakeSigningKey(_private_key.public_key())


@pytest.fixture(autouse=True)
def patch_cognito(monkeypatch):
    """本物のCognitoの代わりに、テスト用の発行者・鍵を使うよう差し替える"""
    monkeypatch.setattr(cognito_auth, "ISSUER", TEST_ISSUER)
    monkeypatch.setattr(cognito_auth, "APP_CLIENT_ID", TEST_AUDIENCE)
    monkeypatch.setattr(cognito_auth, "_jwk_client", lambda: _FakeJWKClient())


def make_token(sub):
    """指定したユーザーID(sub)で署名済みのテスト用トークンを作る"""
    now = int(time.time())
    payload = {
        "sub": sub,
        "iss": TEST_ISSUER,
        "aud": TEST_AUDIENCE,
        "token_use": "id",
        "iat": now,
        "exp": now + 3600,
    }
    return jwt.encode(payload, _private_key, algorithm="RS256")


@pytest.fixture
def app():
    """テスト用のアプリ。DBはメモリ上(sqlite://)に作るので、本番のデータを汚さない。"""
    app = create_app({"TESTING": True, "SQLALCHEMY_DATABASE_URI": "sqlite://"})
    yield app
    with app.app_context():
        db.drop_all()


@pytest.fixture
def client(app):
    """ブラウザ・JS側の代わりにリクエストを送るテスト用クライアント(未認証)"""
    return app.test_client()


def as_user(client, sub):
    """特定のユーザー(sub)としてAuthorizationヘッダーを付けて送るクライアントにする"""
    token = make_token(sub)
    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {token}"
    return client


@pytest.fixture
def auth_client(client):
    """ユーザーID test-user-1 としてログイン済み相当のクライアント"""
    return as_user(client, "test-user-1")
