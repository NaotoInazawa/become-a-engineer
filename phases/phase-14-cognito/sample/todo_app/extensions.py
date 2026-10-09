"""アプリ全体で共有する拡張機能(DB)

create_app() の外で作っておき、create_app() の中でアプリと結び付ける。
"""

from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
