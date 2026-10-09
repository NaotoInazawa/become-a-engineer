// Todo(JavaScript版)
// ページを再読み込みせずに、fetch で API とやり取りして画面を書き換える

const API_URL = "/api/todos";

const form = document.querySelector("#add-form");
const input = document.querySelector("#title-input");
const list = document.querySelector("#todo-list");
const emptyMessage = document.querySelector("#empty");
const errorMessage = document.querySelector("#error");

// API にリクエストを送り、JSON を受け取る共通関数
async function request(url, options = {}) {
  const response = await fetch(url, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });

  if (response.status === 401) {
    // ログインが切れていたらログイン画面へ
    window.location.href = "/login";
    return null;
  }
  if (!response.ok) {
    const data = await response.json();
    throw new Error(data.message);
  }
  // 204 No Content のときは本文がない
  return response.status === 204 ? null : response.json();
}

function showError(message) {
  errorMessage.textContent = message;
  errorMessage.hidden = !message;
}

// Todo 1件分の <li> を作る
function createTodoElement(todo) {
  const li = document.createElement("li");
  li.className = todo.done ? "todo-item done" : "todo-item";

  const toggleButton = document.createElement("button");
  toggleButton.className = "secondary";
  toggleButton.textContent = todo.done ? "戻す" : "完了";
  toggleButton.addEventListener("click", () => toggleTodo(todo));

  const title = document.createElement("span");
  title.className = "title";
  // textContent を使うと、HTMLタグが入力されてもただの文字として表示される(XSS対策)
  title.textContent = todo.title;

  const deleteButton = document.createElement("button");
  deleteButton.className = "danger";
  deleteButton.textContent = "削除";
  deleteButton.addEventListener("click", () => deleteTodo(todo.id));

  li.append(toggleButton, title, deleteButton);
  return li;
}

// 一覧を取得して表示する
async function loadTodos() {
  const todos = await request(API_URL);
  if (todos === null) return;
  list.replaceChildren(...todos.map(createTodoElement));
  emptyMessage.hidden = todos.length > 0;
}

async function addTodo(title) {
  await request(API_URL, {
    method: "POST",
    body: JSON.stringify({ title }),
  });
  await loadTodos();
}

async function toggleTodo(todo) {
  try {
    await request(`${API_URL}/${todo.id}`, {
      method: "PUT",
      body: JSON.stringify({ done: !todo.done }),
    });
    showError("");
    await loadTodos();
  } catch (error) {
    showError(error.message);
  }
}

async function deleteTodo(id) {
  try {
    await request(`${API_URL}/${id}`, { method: "DELETE" });
    showError("");
    await loadTodos();
  } catch (error) {
    showError(error.message);
  }
}

form.addEventListener("submit", async (event) => {
  // フォーム送信によるページ移動を止める(画面遷移せずに処理するため)
  event.preventDefault();
  try {
    await addTodo(input.value);
    input.value = "";
    showError("");
  } catch (error) {
    showError(error.message);
  }
});

loadTodos();
