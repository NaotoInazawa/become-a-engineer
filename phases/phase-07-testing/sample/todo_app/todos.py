"""Todoの画面と処理(ログインが必要)"""

from flask import Blueprint, abort, redirect, render_template, request, url_for
from flask_login import current_user, login_required

from .extensions import db
from .models import Todo

bp = Blueprint("todos", __name__)


def get_own_todo_or_403(todo_id):
    """自分のTodoだけを返す(認可)。他人のTodoなら403エラーにする。"""
    todo = db.get_or_404(Todo, todo_id)
    if todo.user_id != current_user.id:
        abort(403)
    return todo


@bp.route("/")
@login_required
def index():
    todos = (
        db.session.execute(
            db.select(Todo).filter_by(user_id=current_user.id).order_by(Todo.id)
        )
        .scalars()
        .all()
    )
    return render_template("index.html", todos=todos)


@bp.route("/todos", methods=["POST"])
@login_required
def create():
    title = request.form.get("title", "").strip()
    if title:
        db.session.add(Todo(title=title, user_id=current_user.id))
        db.session.commit()
    return redirect(url_for("todos.index"))


@bp.route("/todos/<int:todo_id>/edit", methods=["GET", "POST"])
@login_required
def edit(todo_id):
    todo = get_own_todo_or_403(todo_id)
    if request.method == "POST":
        title = request.form.get("title", "").strip()
        if title:
            todo.title = title
            db.session.commit()
        return redirect(url_for("todos.index"))
    return render_template("edit.html", todo=todo)


@bp.route("/todos/<int:todo_id>/toggle", methods=["POST"])
@login_required
def toggle(todo_id):
    todo = get_own_todo_or_403(todo_id)
    todo.done = not todo.done
    db.session.commit()
    return redirect(url_for("todos.index"))


@bp.route("/todos/<int:todo_id>/delete", methods=["POST"])
@login_required
def delete(todo_id):
    todo = get_own_todo_or_403(todo_id)
    db.session.delete(todo)
    db.session.commit()
    return redirect(url_for("todos.index"))
