"""アプリファクトリ

create_app() を呼ぶたびに、新しいアプリを組み立てて返す。
このフェーズはAPI専用(画面を持たない)ため、登録するBlueprintはapiだけ。
"""

import os

from dotenv import load_dotenv
from flask import Flask, jsonify

from .extensions import db


def create_app(test_config=None):
    load_dotenv()

    app = Flask(__name__)
    app.config.from_mapping(
        SQLALCHEMY_DATABASE_URI="sqlite:///todo.db",
    )
    if test_config is not None:
        app.config.update(test_config)

    db.init_app(app)

    from . import api

    app.register_blueprint(api.bp)

    @app.get("/health")
    def health():
        db.session.execute(db.text("SELECT 1"))
        return jsonify({"status": "ok"})

    @app.errorhandler(404)
    def not_found(error):
        return jsonify({"error": "Not Found", "message": "そのURLは存在しません"}), 404

    with app.app_context():
        db.create_all()

    return app
