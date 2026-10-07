"""アプリ全体で共有する拡張機能(DB・ログイン管理)

create_app() の外で作っておき、create_app() の中でアプリと結び付ける。
"""

from flask_login import LoginManager
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

login_manager = LoginManager()
login_manager.login_view = "auth.login"
login_manager.login_message = "ログインしてください"
