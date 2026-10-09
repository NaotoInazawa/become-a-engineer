"""Todo の REST API(JSON を返す)

フェーズ8との違い:認証がFlask-Login(セッションCookie)ではなく、
Cognitoが発行したJWTトークン(Authorizationヘッダー)になっている。
"""

from flask import Blueprint, abort, g, jsonify, request

from .cognito_auth import cognito_auth_required
from .extensions import db
from .models import Todo

bp = Blueprint("api", __name__, url_prefix="/api")

TITLE_MAX_LENGTH = 100


def todo_to_dict(todo):
    """Todo を JSON に変換できる辞書にする"""
    return {
        "id": todo.id,
        "title": todo.title,
        "done": todo.done,
        "created_at": todo.created_at.isoformat(),
    }


def get_own_todo_or_403(todo_id):
    todo = db.get_or_404(Todo, todo_id)
    if todo.cognito_sub != g.cognito_sub:
        abort(403)
    return todo


def validate_title(data):
    """タイトルを検証する。問題があれば 400 エラーにする。"""
    title = data.get("title")
    if not isinstance(title, str) or not title.strip():
        abort(400, description="title は必須です")
    title = title.strip()
    if len(title) > TITLE_MAX_LENGTH:
        abort(400, description=f"title は{TITLE_MAX_LENGTH}文字以内にしてください")
    return title


@bp.get("/todos")
@cognito_auth_required
def list_todos():
    """一覧を取得する:GET /api/todos"""
    todos = (
        db.session.execute(
            db.select(Todo).filter_by(cognito_sub=g.cognito_sub).order_by(Todo.id)
        )
        .scalars()
        .all()
    )
    return jsonify([todo_to_dict(todo) for todo in todos])


@bp.post("/todos")
@cognito_auth_required
def create_todo():
    """追加する:POST /api/todos  {"title": "..."}"""
    data = request.get_json(silent=True) or {}
    title = validate_title(data)
    todo = Todo(title=title, cognito_sub=g.cognito_sub)
    db.session.add(todo)
    db.session.commit()
    # 201 Created:新しく作成されたことを表すステータスコード
    return jsonify(todo_to_dict(todo)), 201


@bp.get("/todos/<int:todo_id>")
@cognito_auth_required
def get_todo(todo_id):
    """1件取得する:GET /api/todos/<id>"""
    return jsonify(todo_to_dict(get_own_todo_or_403(todo_id)))


@bp.put("/todos/<int:todo_id>")
@cognito_auth_required
def update_todo(todo_id):
    """更新する:PUT /api/todos/<id>  {"title": "...", "done": true}"""
    todo = get_own_todo_or_403(todo_id)
    data = request.get_json(silent=True) or {}
    if "title" in data:
        todo.title = validate_title(data)
    if "done" in data:
        if not isinstance(data["done"], bool):
            abort(400, description="done は true か false で指定してください")
        todo.done = data["done"]
    db.session.commit()
    return jsonify(todo_to_dict(todo))


@bp.delete("/todos/<int:todo_id>")
@cognito_auth_required
def delete_todo(todo_id):
    """削除する:DELETE /api/todos/<id>"""
    todo = get_own_todo_or_403(todo_id)
    db.session.delete(todo)
    db.session.commit()
    # 204 No Content:成功したが、返すデータはない
    return "", 204


@bp.errorhandler(400)
@bp.errorhandler(401)
@bp.errorhandler(403)
@bp.errorhandler(404)
def handle_error(error):
    """API のエラーは HTML ではなく JSON で返す"""
    return jsonify({"error": error.name, "message": error.description}), error.code
