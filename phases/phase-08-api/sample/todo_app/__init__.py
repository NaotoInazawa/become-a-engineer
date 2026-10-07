"""アプリファクトリ

create_app() を呼ぶたびに、新しいアプリを組み立てて返す。
本番では通常の設定で、テストではテスト用の設定(別のDBなど)で作れるようになる。
"""

import os

from dotenv import load_dotenv
from flask import Flask, render_template

from .extensions import db, login_manager


def create_app(test_config=None):
    load_dotenv()

    app = Flask(__name__)
    app.config.from_mapping(
        SECRET_KEY=os.environ.get("SECRET_KEY"),
        SQLALCHEMY_DATABASE_URI="sqlite:///todo.db",
        # 他のサイトから送られたリクエストに、セッションCookieを付けない(CSRF対策の一つ)
        SESSION_COOKIE_SAMESITE="Lax",
    )
    # テスト用の設定が渡されたら上書きする
    if test_config is not None:
        app.config.update(test_config)

    if not app.config["SECRET_KEY"]:
        raise RuntimeError("SECRET_KEY が設定されていません(.env を確認してください)")

    db.init_app(app)
    login_manager.init_app(app)

    from . import api, auth, todos

    app.register_blueprint(auth.bp)
    app.register_blueprint(todos.bp)
    app.register_blueprint(api.bp)

    @app.errorhandler(403)
    def forbidden(error):
        return render_template("403.html"), 403

    @app.errorhandler(404)
    def not_found(error):
        return render_template("404.html"), 404

    with app.app_context():
        db.create_all()

    return app
