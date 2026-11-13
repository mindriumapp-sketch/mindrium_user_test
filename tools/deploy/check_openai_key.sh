#!/usr/bin/env bash
# 배포용 키가 살아 있고 설정한 모델을 쓸 수 있는지 확인한다.
#
#   tools/deploy/check_openai_key.sh <env 파일>
#
# 모델 조회 API만 호출한다(토큰을 쓰지 않음). 키와 응답 본문은 출력하지 않고 결과 코드만 보여 준다.
# 모델 이름이 틀렸거나 새 키의 프로젝트에 그 모델 권한이 없으면 여기서 걸린다.
set -u
ENV_FILE="${1:-}"
[ -f "$ENV_FILE" ] || { echo "사용법: $0 <env 파일>" >&2; exit 2; }

get() { grep -E "^$1=" "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '[:space:]"'"'"; }
KEY="$(get OPENAI_API_KEY)"; MODEL="$(get OPENAI_MODEL)"; BASE="$(get OPENAI_API_BASE)"
BASE="${BASE:-https://api.openai.com/v1}"; MODEL="${MODEL:-gpt-6-luna}"
[ -n "$KEY" ] || { echo "FAIL OPENAI_API_KEY가 비어 있음"; exit 1; }

FAIL=0
check() { # 이름 URL
  code=$(curl -s -m 15 -o /dev/null -w '%{http_code}' "$2" -H "Authorization: Bearer $KEY")
  case "$code" in
    200) echo "  OK   $1" ;;
    401) echo "  FAIL $1 → 401: 키가 틀렸거나 폐기됨"; FAIL=1 ;;
    403|404) echo "  FAIL $1 → $code: 이 키의 프로젝트에 해당 모델 권한이 없거나 모델 이름이 틀림"; FAIL=1 ;;
    429) echo "  FAIL $1 → 429: 한도 초과(결제·사용 한도 확인)"; FAIL=1 ;;
    *)   echo "  FAIL $1 → $code (네트워크 또는 서버 문제)"; FAIL=1 ;;
  esac
}
echo "[OpenAI 키 점검] 모델=$MODEL"
check "키 유효성(모델 목록)" "$BASE/models"
check "상담 모델 사용 가능($MODEL)" "$BASE/models/$MODEL"
unset KEY
[ $FAIL -eq 0 ] && echo "통과" || { echo "실패 항목을 해결한 뒤 다시 실행하세요."; exit 1; }
