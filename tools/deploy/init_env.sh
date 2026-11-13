#!/usr/bin/env bash
# 배포용 환경 변수 파일을 만든다. 키는 화면과 셸 기록에 남지 않게 숨김 입력으로 받는다.
#
#   tools/deploy/init_env.sh <만들 파일 경로> [DB_NAME]
#   예) tools/deploy/init_env.sh ~/secrets/mindrium-demo.env mindrium_demo
#
# - 개발용 키(backend/app/.env)와 같은 키는 거부한다. 배포는 별도 키를 쓴다.
# - JWT 비밀 값은 새로 무작위로 만든다(개발 값과 공유하지 않는다).
# - 파일은 소유자만 읽도록(600) 만든다. 저장소 안에 만들면 git 무시 대상인지 확인한다.
set -euo pipefail

OUT="${1:-}"
DB_NAME="${2:-mindrium_demo}"
[ -n "$OUT" ] || { echo "사용법: $0 <만들 파일 경로> [DB_NAME]" >&2; exit 2; }
[ ! -e "$OUT" ] || { echo "이미 있는 파일입니다: $OUT (덮어쓰지 않음)" >&2; exit 2; }

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DEV_ENV="$REPO/backend/app/.env"

# 저장소 안에 만든다면 반드시 git 무시 대상이어야 한다.
OUT_DIR="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd)" || { echo "폴더가 없습니다: $(dirname "$OUT")" >&2; exit 2; }
OUT_ABS="$OUT_DIR/$(basename "$OUT")"
case "$OUT_ABS" in "$REPO"/*)
  git -C "$REPO" check-ignore -q "$OUT_ABS" \
    || { echo "저장소 안의 이 경로는 git 무시 대상이 아닙니다. 저장소 밖 경로를 쓰세요: $OUT_ABS" >&2; exit 2; } ;;
esac

read -r -s -p "배포용 OPENAI_API_KEY (입력이 화면에 보이지 않음): " KEY; echo
KEY="$(printf '%s' "$KEY" | tr -d '[:space:]"'"'")"
[ "${#KEY}" -ge 20 ] && case "$KEY" in sk-*) ;; *) false ;; esac \
  || { echo "OpenAI 키 형식(sk-...)이 아닙니다." >&2; exit 2; }

if [ -f "$DEV_ENV" ]; then
  DEV_KEY="$(grep -E '^OPENAI_API_KEY=' "$DEV_ENV" | head -1 | cut -d= -f2- | tr -d '[:space:]"'"'")"
  if [ -n "$DEV_KEY" ] && [ "$KEY" = "$DEV_KEY" ]; then
    echo "개발용(backend/app/.env)과 같은 키입니다. 배포용 별도 키를 넣으세요." >&2; exit 2
  fi
fi

read -r -p "MONGO_URI [mongodb://host.docker.internal:27017]: " MONGO_URI
MONGO_URI="${MONGO_URI:-mongodb://host.docker.internal:27017}"
read -r -p "OPENAI_MODEL [gpt-6-luna]: " MODEL
MODEL="${MODEL:-gpt-6-luna}"

rand() { python3 -c 'import secrets; print(secrets.token_urlsafe(48))'; }

umask 077
{
  echo "# 배포용 환경 변수 (git에 올리지 않는다. 형식은 backend/app/.env.example 참고)"
  echo "# 만든 시각: $(date '+%F %T')"
  echo "MONGO_URI=$MONGO_URI"
  echo "DB_NAME=$DB_NAME"
  echo "JWT_SECRET=$(rand)"
  echo "JWT_REFRESH_SECRET=$(rand)"
  echo "OPENAI_API_KEY=$KEY"
  echo "OPENAI_MODEL=$MODEL"
  echo "OPENAI_EMBEDDING_MODEL=text-embedding-3-large"
  echo "OPENAI_API_BASE=https://api.openai.com/v1"
  echo "API_PORT=8070"
  echo "CORS_ORIGINS=http://localhost:56000"
} > "$OUT_ABS"
chmod 600 "$OUT_ABS"
unset KEY DEV_KEY

echo "만들었습니다: $OUT_ABS (권한 600, DB_NAME=$DB_NAME, 모델=$MODEL)"
echo "다음: tools/deploy/check_openai_key.sh $OUT_ABS"
