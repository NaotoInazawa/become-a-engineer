"""ターミナルで動くTodoアプリ

使い方:
    python todo_cli.py
"""

import json
from pathlib import Path

DATA_FILE = Path(__file__).parent / "todos.json"


def load_todos():
    if not DATA_FILE.exists():
        return []
    with DATA_FILE.open(encoding="utf-8") as f:
        return json.load(f)


def save_todos(todos):
    with DATA_FILE.open("w", encoding="utf-8") as f:
        json.dump(todos, f, ensure_ascii=False, indent=2)


def next_id(todos):
    if not todos:
        return 1
    return max(todo["id"] for todo in todos) + 1


def add_todo(todos, title):
    todo = {"id": next_id(todos), "title": title, "done": False}
    todos.append(todo)
    return todo


def list_todos(todos):
    if not todos:
        print("Todoはありません")
        return
    for todo in todos:
        mark = "x" if todo["done"] else " "
        print(f"[{mark}] {todo['id']}: {todo['title']}")


def delete_todo(todos, todo_id):
    for todo in todos:
        if todo["id"] == todo_id:
            todos.remove(todo)
            return True
    return False


def main():
    todos = load_todos()
    print("Todoアプリ(コマンド: add / list / delete / quit)")

    while True:
        command = input("> ").strip()

        if command == "add":
            title = input("タイトル: ").strip()
            if title:
                todo = add_todo(todos, title)
                save_todos(todos)
                print(f"追加しました: {todo['id']}: {todo['title']}")
            else:
                print("タイトルを入力してください")

        elif command == "list":
            list_todos(todos)

        elif command == "delete":
            todo_id = int(input("削除するID: "))
            if delete_todo(todos, todo_id):
                save_todos(todos)
                print("削除しました")
            else:
                print("そのIDのTodoはありません")

        elif command == "quit":
            print("終了します")
            break

        else:
            print("不明なコマンドです")


if __name__ == "__main__":
    main()
