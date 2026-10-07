"""DB版Todoアプリ(フェーズ4 完成版)

データはSQLiteデータベース(instance/todo.db)に保存されるため、
サーバーを再起動しても消えません。

起動方法:
    flask --app app run --debug --port 5001
"""

from datetime import datetime

from flask import Flask, redirect, render_template, request, url_for
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

# 接続するデータベースの場所。sqlite:/// の後ろはファイル名(instance/ フォルダに作られる)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///todo.db"
# True にすると、実行されたSQLがターミナルに表示される(学習用)
app.config["SQLALCHEMY_ECHO"] = True

db = SQLAlchemy(app)


class Todo(db.Model):
    """todo テーブルに対応するクラス(モデル)"""

    id = db.Column(db.Integer, primary_key=True)  # 主キー(自動で連番になる)
    title = db.Column(db.String(100), nullable=False)
    done = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.now)


# テーブルがなければ作成する
with app.app_context():
    db.create_all()


@app.route("/")
def index():
    """一覧ページ:SELECT * FROM todo ORDER BY id"""
    todos = db.session.execute(db.select(Todo).order_by(Todo.id)).scalars().all()
    return render_template("index.html", todos=todos)


@app.route("/todos", methods=["POST"])
def create():
    """追加:INSERT INTO todo ..."""
    title = request.form.get("title", "").strip()
    if title:
        db.session.add(Todo(title=title))
        db.session.commit()
    return redirect(url_for("index"))


@app.route("/todos/<int:todo_id>/edit", methods=["GET", "POST"])
def edit(todo_id):
    """編集:UPDATE todo SET title = ... WHERE id = ..."""
    todo = db.get_or_404(Todo, todo_id)
    if request.method == "POST":
        title = request.form.get("title", "").strip()
        if title:
            todo.title = title
            db.session.commit()
        return redirect(url_for("index"))
    return render_template("edit.html", todo=todo)


@app.route("/todos/<int:todo_id>/toggle", methods=["POST"])
def toggle(todo_id):
    """完了・未完了の切り替え:UPDATE todo SET done = ... WHERE id = ..."""
    todo = db.get_or_404(Todo, todo_id)
    todo.done = not todo.done
    db.session.commit()
    return redirect(url_for("index"))


@app.route("/todos/<int:todo_id>/delete", methods=["POST"])
def delete(todo_id):
    """削除:DELETE FROM todo WHERE id = ..."""
    todo = db.get_or_404(Todo, todo_id)
    db.session.delete(todo)
    db.session.commit()
    return redirect(url_for("index"))


@app.errorhandler(404)
def not_found(error):
    return render_template("404.html"), 404
