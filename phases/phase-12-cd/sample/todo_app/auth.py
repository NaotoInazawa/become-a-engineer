"""認証(ユーザー登録・ログイン・ログアウト)"""

from flask import Blueprint, flash, redirect, render_template, request, url_for
from flask_login import login_required, login_user, logout_user

from .extensions import db
from .models import User

bp = Blueprint("auth", __name__)


@bp.route("/register", methods=["GET", "POST"])
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
            return redirect(url_for("todos.index"))
    return render_template("register.html")


@bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        user = db.session.execute(db.select(User).filter_by(username=username)).scalar()
        if user is None or not user.check_password(password):
            flash("ユーザー名またはパスワードが違います")
        else:
            login_user(user)
            return redirect(url_for("todos.index"))
    return render_template("login.html")


@bp.route("/logout", methods=["POST"])
@login_required
def logout():
    logout_user()
    return redirect(url_for("auth.login"))
