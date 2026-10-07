"""REST API のテスト

画面のHTMLではなく、ステータスコードとJSONの中身を確認する。
"""

from .conftest import register


def create(client, title="牛乳を買う"):
    return client.post("/api/todos", json={"title": title})


def test_list_requires_login(client):
    """未ログインなら401(リダイレクトではない)"""
    response = client.get("/api/todos")

    assert response.status_code == 401
    assert response.get_json()["error"] == "Unauthorized"


def test_create_and_list(logged_in_client):
    """追加すると201と作成されたTodoが返り、一覧に含まれる"""
    response = create(logged_in_client)

    assert response.status_code == 201
    assert response.get_json()["title"] == "牛乳を買う"
    assert response.get_json()["done"] is False

    todos = logged_in_client.get("/api/todos").get_json()
    assert [todo["title"] for todo in todos] == ["牛乳を買う"]


def test_create_without_title(logged_in_client):
    """titleがないと400"""
    response = logged_in_client.post("/api/todos", json={})

    assert response.status_code == 400
    assert "title" in response.get_json()["message"]


def test_create_with_too_long_title(logged_in_client):
    """境界値:100文字はOK、101文字は400"""
    assert create(logged_in_client, "あ" * 100).status_code == 201
    assert create(logged_in_client, "あ" * 101).status_code == 400


def test_update(logged_in_client):
    """タイトルと完了状態を更新できる"""
    todo_id = create(logged_in_client).get_json()["id"]

    response = logged_in_client.put(
        f"/api/todos/{todo_id}", json={"title": "卵を買う", "done": True}
    )

    assert response.status_code == 200
    assert response.get_json()["title"] == "卵を買う"
    assert response.get_json()["done"] is True


def test_update_with_invalid_done(logged_in_client):
    """doneが真偽値でなければ400"""
    todo_id = create(logged_in_client).get_json()["id"]

    response = logged_in_client.put(f"/api/todos/{todo_id}", json={"done": "yes"})

    assert response.status_code == 400


def test_delete(logged_in_client):
    """削除すると204が返り、一覧から消える"""
    todo_id = create(logged_in_client).get_json()["id"]

    response = logged_in_client.delete(f"/api/todos/{todo_id}")

    assert response.status_code == 204
    assert logged_in_client.get("/api/todos").get_json() == []


def test_not_found(logged_in_client):
    """存在しないTodoは404(JSON)"""
    response = logged_in_client.get("/api/todos/999")

    assert response.status_code == 404
    assert response.is_json


def test_cannot_access_other_users_todo(client):
    """他人のTodoは取得・更新・削除できない(403)"""
    register(client, "alice")
    todo_id = create(client).get_json()["id"]
    client.post("/logout")

    register(client, "bob")

    assert client.get("/api/todos").get_json() == []
    assert client.get(f"/api/todos/{todo_id}").status_code == 403
    assert client.put(f"/api/todos/{todo_id}", json={"done": True}).status_code == 403
    assert client.delete(f"/api/todos/{todo_id}").status_code == 403
