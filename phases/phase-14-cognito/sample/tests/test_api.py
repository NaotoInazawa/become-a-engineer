"""REST API のテスト

画面のHTMLではなく、ステータスコードとJSONの中身を確認する。
認証は「正しいトークンを送っているかどうか」で判定する。
"""

from .conftest import as_user


def create(client, title="牛乳を買う"):
    return client.post("/api/todos", json={"title": title})


def test_list_requires_token(client):
    """Authorizationヘッダーがなければ401"""
    response = client.get("/api/todos")

    assert response.status_code == 401


def test_list_with_invalid_token(client):
    """トークンの形式が壊れていれば401"""
    client.environ_base["HTTP_AUTHORIZATION"] = "Bearer not-a-real-token"
    response = client.get("/api/todos")

    assert response.status_code == 401


def test_create_and_list(auth_client):
    """追加すると201と作成されたTodoが返り、一覧に含まれる"""
    response = create(auth_client)

    assert response.status_code == 201
    assert response.get_json()["title"] == "牛乳を買う"
    assert response.get_json()["done"] is False

    todos = auth_client.get("/api/todos").get_json()
    assert [todo["title"] for todo in todos] == ["牛乳を買う"]


def test_create_without_title(auth_client):
    """titleがないと400"""
    response = auth_client.post("/api/todos", json={})

    assert response.status_code == 400
    assert "title" in response.get_json()["message"]


def test_create_with_too_long_title(auth_client):
    """境界値:100文字はOK、101文字は400"""
    assert create(auth_client, "あ" * 100).status_code == 201
    assert create(auth_client, "あ" * 101).status_code == 400


def test_update(auth_client):
    """タイトルと完了状態を更新できる"""
    todo_id = create(auth_client).get_json()["id"]

    response = auth_client.put(
        f"/api/todos/{todo_id}", json={"title": "卵を買う", "done": True}
    )

    assert response.status_code == 200
    assert response.get_json()["title"] == "卵を買う"
    assert response.get_json()["done"] is True


def test_update_with_invalid_done(auth_client):
    """doneが真偽値でなければ400"""
    todo_id = create(auth_client).get_json()["id"]

    response = auth_client.put(f"/api/todos/{todo_id}", json={"done": "yes"})

    assert response.status_code == 400


def test_delete(auth_client):
    """削除すると204が返り、一覧から消える"""
    todo_id = create(auth_client).get_json()["id"]

    response = auth_client.delete(f"/api/todos/{todo_id}")

    assert response.status_code == 204
    assert auth_client.get("/api/todos").get_json() == []


def test_not_found(auth_client):
    """存在しないTodoは404(JSON)"""
    response = auth_client.get("/api/todos/999")

    assert response.status_code == 404
    assert response.is_json


def test_cannot_access_other_users_todo(client):
    """他人(別のsub)のTodoは取得・更新・削除できない(403)"""
    alice = as_user(client, "alice-sub")
    todo_id = create(alice).get_json()["id"]

    bob = as_user(client, "bob-sub")

    assert bob.get("/api/todos").get_json() == []
    assert bob.get(f"/api/todos/{todo_id}").status_code == 403
    assert bob.put(f"/api/todos/{todo_id}", json={"done": True}).status_code == 403
    assert bob.delete(f"/api/todos/{todo_id}").status_code == 403


def test_health_does_not_require_token(client):
    """/healthは認証なしでアクセスできる"""
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}
