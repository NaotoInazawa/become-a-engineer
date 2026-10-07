"""認証(ユーザー登録・ログイン・ログアウト)のテスト"""

from todo_app.extensions import db
from todo_app.models import User

from .conftest import login, register


def test_register_creates_user(client, app):
    """正常系:ユーザー登録すると、ユーザーがDBに保存される"""
    response = register(client, "alice", "password123")

    assert response.status_code == 200
    with app.app_context():
        user = db.session.execute(db.select(User).filter_by(username="alice")).scalar()
        assert user is not None


def test_password_is_hashed(client, app):
    """パスワードは平文ではなく、ハッシュ化されて保存される"""
    register(client, "alice", "password123")

    with app.app_context():
        user = db.session.execute(db.select(User).filter_by(username="alice")).scalar()
        assert user.password_hash != "password123"
        assert user.check_password("password123")


def test_register_duplicate_username(client):
    """異常系:同じユーザー名では登録できない"""
    register(client, "alice")
    client.post("/logout")

    response = register(client, "alice")

    assert "そのユーザー名は既に使われています" in response.get_data(as_text=True)


def test_login_success(client):
    """正常系:正しいパスワードでログインできる"""
    register(client)
    client.post("/logout")

    response = login(client)

    assert "alice さん" in response.get_data(as_text=True)


def test_login_wrong_password(client):
    """異常系:パスワードが違うとログインできない"""
    register(client)
    client.post("/logout")

    response = login(client, password="wrong-password")

    assert "ユーザー名またはパスワードが違います" in response.get_data(as_text=True)


def test_index_requires_login(client):
    """未ログインで一覧を開くと、ログイン画面へリダイレクトされる"""
    response = client.get("/")

    assert response.status_code == 302
    assert "/login" in response.headers["Location"]
