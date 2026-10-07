"""ヘルスチェックのテスト"""


def test_health(client):
    """ログインしていなくても、200 と {"status": "ok"} が返る"""
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}
