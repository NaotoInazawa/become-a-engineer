"""Flask版Todoアプリ(フェーズ3 完成版)

データはメモリ上(Pythonのリスト)に保存するため、サーバーを止めると消えます。

起動方法:
    flask --app app run --debug --port 5001
"""

from flask import Flask, abort, redirect, render_template, request, url_for

app = Flask(__name__)

# Todoの一覧(メモリ上に保存)
todos = []


def next_id():
    """まだ使われていない次のIDを返す。"""
    if not todos:
        return 1
    return max(todo["id"] for todo in todos) + 1


def find_todo(todo_id):
    """IDに一致するTodoを返す。見つからなければ404エラーにする。"""
    for todo in todos:
        if todo["id"] == todo_id:
            return todo
    abort(404)


@app.route("/")
def index():
    """一覧ページ(GET /)"""
    return render_template("index.html", todos=todos)


@app.route("/todos", methods=["POST"])
def create():
    """Todoを追加する(POST /todos)"""
    title = request.form.get("title", "").strip()
    if title:
        todos.append({"id": next_id(), "title": title, "done": False})
    # POSTの後は一覧ページへリダイレクトする(PRGパターン)
    return redirect(url_for("index"))


@app.route("/todos/<int:todo_id>/edit", methods=["GET", "POST"])
def edit(todo_id):
    """編集ページの表示(GET)と、更新の実行(POST)"""
    todo = find_todo(todo_id)
    if request.method == "POST":
        title = request.form.get("title", "").strip()
        if title:
            todo["title"] = title
        return redirect(url_for("index"))
    return render_template("edit.html", todo=todo)


@app.route("/todos/<int:todo_id>/delete", methods=["POST"])
def delete(todo_id):
    """Todoを削除する(POST /todos/<id>/delete)"""
    todo = find_todo(todo_id)
    todos.remove(todo)
    return redirect(url_for("index"))


@app.errorhandler(404)
def not_found(error):
    """404エラーのときに表示するページ"""
    return render_template("404.html"), 404
