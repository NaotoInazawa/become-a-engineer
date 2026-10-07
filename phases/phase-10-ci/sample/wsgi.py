"""gunicorn から読み込まれる入り口

起動例:
    gunicorn --bind 127.0.0.1:8000 wsgi:app
"""

from todo_app import create_app

app = create_app()
