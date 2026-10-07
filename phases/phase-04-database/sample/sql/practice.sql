-- フェーズ4 Step 1:SQLの手動練習用
-- 実行方法: sqlite3 practice.db < sql/practice.sql
-- または sqlite3 practice.db で対話モードに入り、1文ずつ実行する

-- テーブルを作成する
CREATE TABLE IF NOT EXISTS todo (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    done INTEGER NOT NULL DEFAULT 0
);

-- データを追加する(INSERT)
INSERT INTO todo (title) VALUES ('牛乳を買う');
INSERT INTO todo (title) VALUES ('本を読む');
INSERT INTO todo (title, done) VALUES ('部屋を掃除する', 1);

-- すべて取得する(SELECT)
SELECT * FROM todo;

-- 条件を付けて取得する(WHERE)
SELECT * FROM todo WHERE done = 0;

-- 並べ替える(ORDER BY)
SELECT * FROM todo ORDER BY id DESC;

-- 更新する(UPDATE)
UPDATE todo SET done = 1 WHERE id = 1;

-- 削除する(DELETE)
DELETE FROM todo WHERE id = 2;

-- 結果を確認する
SELECT * FROM todo;
