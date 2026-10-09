"""Cognitoが発行したJWT(JSON Web Token)を検証する仕組み

Flask-Loginの「セッションCookie」の代わりに、このフェーズでは
「リクエストのたびにAuthorizationヘッダーで送られてくるトークンを検証する」
方式(JWT認証)を使う。サーバー側はログイン状態を一切覚えない(ステートレス)。
"""

import os
from functools import lru_cache, wraps

import jwt
from flask import abort, g, request
from jwt import PyJWKClient

USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID", "")
APP_CLIENT_ID = os.environ.get("COGNITO_APP_CLIENT_ID", "")
AWS_REGION = os.environ.get("AWS_REGION", "ap-northeast-1")

ISSUER = f"https://cognito-idp.{AWS_REGION}.amazonaws.com/{USER_POOL_ID}"
JWKS_URL = f"{ISSUER}/.well-known/jwks.json"


@lru_cache(maxsize=1)
def _jwk_client():
    # Cognitoの公開鍵(署名を検証するための鍵)を取得するクライアント。
    # 鍵は頻繁に変わらないため、プロセス内でキャッシュして毎回の取得を避ける。
    return PyJWKClient(JWKS_URL)


def cognito_auth_required(view):
    """Authorizationヘッダーのトークンを検証し、問題なければ g.cognito_sub にユーザーIDを入れる"""

    @wraps(view)
    def wrapped(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            abort(401, description="Authorizationヘッダーがありません")

        token = auth_header.removeprefix("Bearer ")
        try:
            signing_key = _jwk_client().get_signing_key_from_jwt(token)
            claims = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256"],
                issuer=ISSUER,
                # IDトークン(ログインしたユーザー自身の情報)を想定し、audienceを検証する
                audience=APP_CLIENT_ID,
            )
        except jwt.PyJWTError as error:
            abort(401, description=f"トークンが無効です: {error}")

        g.cognito_sub = claims["sub"]
        return view(*args, **kwargs)

    return wrapped
