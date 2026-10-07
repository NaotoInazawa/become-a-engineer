"""テスト全体で使う準備(フィクスチャ)

pytest は、テスト関数の引数名と同じ名前のフィクスチャを自動で渡してくれる。
"""

import pytest

from todo_app import create_app
from todo_app.extensions import db


@pytest.fixture
def app():
    """テスト用のアプリ。DBはメモリ上(sqlite://)に作るので、本番のデータを汚さない。"""
    app = create_app(
        {
            "TESTING": True,
            "SECRET_KEY": "test",
            "SQLALCHEMY_DATABASE_URI": "sqlite://",
        }
    )
    yield app
    # テストが終わったら、テーブルを削除して後片付けする
    with app.app_context():
        db.drop_all()


@pytest.fixture
def client(app):
    """ブラウザの代わりにリクエストを送るテスト用クライアント"""
    return app.test_client()


def register(client, username="alice", password="password123"):
    return client.post(
        "/register",
        data={"username": username, "password": password},
        follow_redirects=True,
    )


def login(client, username="alice", password="password123"):
    return client.post(
        "/login",
        data={"username": username, "password": password},
        follow_redirects=True,
    )


@pytest.fixture
def logged_in_client(client):
    """ユーザー登録済み・ログイン済みのクライアント"""
    register(client)
    return client
