"""Todo機能(CRUD・認可)のテスト"""

from todo_app.extensions import db
from todo_app.models import Todo

from .conftest import register


def test_create_todo(logged_in_client):
    """正常系:Todoを追加すると一覧に表示される"""
    response = logged_in_client.post(
        "/todos", data={"title": "牛乳を買う"}, follow_redirects=True
    )

    assert response.status_code == 200
    assert "牛乳を買う" in response.get_data(as_text=True)


def test_create_todo_with_empty_title(logged_in_client, app):
    """異常系:空のタイトルでは追加されない"""
    logged_in_client.post("/todos", data={"title": "   "})

    with app.app_context():
        assert db.session.execute(db.select(Todo)).scalars().all() == []


def test_edit_todo(logged_in_client):
    """正常系:Todoのタイトルを編集できる"""
    logged_in_client.post("/todos", data={"title": "牛乳を買う"})

    response = logged_in_client.post(
        "/todos/1/edit", data={"title": "卵を買う"}, follow_redirects=True
    )

    body = response.get_data(as_text=True)
    assert "卵を買う" in body
    assert "牛乳を買う" not in body


def test_toggle_todo(logged_in_client, app):
    """正常系:完了・未完了を切り替えられる"""
    logged_in_client.post("/todos", data={"title": "牛乳を買う"})

    logged_in_client.post("/todos/1/toggle")
    with app.app_context():
        assert db.session.get(Todo, 1).done is True

    logged_in_client.post("/todos/1/toggle")
    with app.app_context():
        assert db.session.get(Todo, 1).done is False


def test_delete_todo(logged_in_client):
    """正常系:Todoを削除できる"""
    logged_in_client.post("/todos", data={"title": "牛乳を買う"})

    response = logged_in_client.post("/todos/1/delete", follow_redirects=True)

    assert "牛乳を買う" not in response.get_data(as_text=True)


def test_edit_not_found(logged_in_client):
    """異常系:存在しないTodoは404"""
    response = logged_in_client.get("/todos/999/edit")

    assert response.status_code == 404


def test_cannot_see_other_users_todo(client):
    """認可:他人のTodoは一覧に表示されない"""
    register(client, "alice")
    client.post("/todos", data={"title": "aliceのTodo"})
    client.post("/logout")

    register(client, "bob")
    response = client.get("/")

    assert "aliceのTodo" not in response.get_data(as_text=True)


def test_cannot_edit_other_users_todo(client):
    """認可:他人のTodoを編集・削除しようとすると403"""
    register(client, "alice")
    client.post("/todos", data={"title": "aliceのTodo"})
    client.post("/logout")

    register(client, "bob")

    assert client.get("/todos/1/edit").status_code == 403
    assert client.post("/todos/1/edit", data={"title": "乗っ取り"}).status_code == 403
    assert client.post("/todos/1/toggle").status_code == 403
    assert client.post("/todos/1/delete").status_code == 403
