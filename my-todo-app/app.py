"""ログイン付きTodoアプリ

起動方法:
    cp .env.example .env   # SECRET_KEY を設定する
    flask --app app run --debug --port 5001
"""

import os
from datetime import datetime

from dotenv import load_dotenv
from flask import Flask, abort, flash, redirect, render_template, request, url_for
from flask_login import (
    LoginManager,
    UserMixin,
    current_user,
    login_required,
    login_user,
    logout_user,
)
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import check_password_hash, generate_password_hash

load_dotenv()

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ["SECRET_KEY"]
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///todo.db"

db = SQLAlchemy(app)

login_manager = LoginManager(app)
login_manager.login_view = "login"
login_manager.login_message = "ログインしてください"


class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    todos = db.relationship("Todo", back_populates="user", cascade="all, delete-orphan")

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)


class Todo(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    done = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.now)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    user = db.relationship("User", back_populates="todos")


with app.app_context():
    db.create_all()


@login_manager.user_loader
def load_user(user_id):
    return db.session.get(User, int(user_id))


def get_own_todo_or_403(todo_id):
    todo = db.get_or_404(Todo, todo_id)
    if todo.user_id != current_user.id:
        abort(403)
    return todo


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        if not username or not password:
            flash("ユーザー名とパスワードを入力してください")
        elif db.session.execute(db.select(User).filter_by(username=username)).scalar():
            flash("そのユーザー名は既に使われています")
        else:
            user = User(username=username)
            user.set_password(password)
            db.session.add(user)
            db.session.commit()
            login_user(user)
            return redirect(url_for("index"))
    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        user = db.session.execute(db.select(User).filter_by(username=username)).scalar()
        if user is None or not user.check_password(password):
            flash("ユーザー名またはパスワードが違います")
        else:
            login_user(user)
            return redirect(url_for("index"))
    return render_template("login.html")


@app.route("/logout", methods=["POST"])
@login_required
def logout():
    logout_user()
    return redirect(url_for("login"))


@app.route("/")
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


@app.route("/todos", methods=["POST"])
@login_required
def create():
    title = request.form.get("title", "").strip()
    if title:
        db.session.add(Todo(title=title, user_id=current_user.id))
        db.session.commit()
    return redirect(url_for("index"))


@app.route("/todos/<int:todo_id>/edit", methods=["GET", "POST"])
@login_required
def edit(todo_id):
    todo = get_own_todo_or_403(todo_id)
    if request.method == "POST":
        title = request.form.get("title", "").strip()
        if title:
            todo.title = title
            db.session.commit()
        return redirect(url_for("index"))
    return render_template("edit.html", todo=todo)


@app.route("/todos/<int:todo_id>/toggle", methods=["POST"])
@login_required
def toggle(todo_id):
    todo = get_own_todo_or_403(todo_id)
    todo.done = not todo.done
    db.session.commit()
    return redirect(url_for("index"))


@app.route("/todos/<int:todo_id>/delete", methods=["POST"])
@login_required
def delete(todo_id):
    todo = get_own_todo_or_403(todo_id)
    db.session.delete(todo)
    db.session.commit()
    return redirect(url_for("index"))


@app.errorhandler(403)
def forbidden(error):
    return render_template("403.html"), 403


@app.errorhandler(404)
def not_found(error):
    return render_template("404.html"), 404
