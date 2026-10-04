#!/usr/bin/env bash
# 시연 직전 환경 점검 (docs/chatbot_HANDOVER.md 7절).
#
#   DEMO_PASSWORD='<데모 계정 비밀번호>' tools/demo/preflight.sh            # 점검만
#   DEMO_PASSWORD='<데모 계정 비밀번호>' tools/demo/preflight.sh --install  # + 데모 빌드 설치
#
# 상담 품질이 아니라 시연을 망치는 환경 문제(서버 미재시작, 플래그 누락,
# adb 포워딩 끊김, 계정·데이터 누락)를 잡는다. 비밀번호와 토큰은 출력하지 않는다.
set -u
cd "$(dirname "$0")/../.."

BASE=http://127.0.0.1:8090
EMAIL=mindrium.demo@example.com
EXPECTED_PROMPT=respond_v14
FAIL=0
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=1; }
info() { printf '       %s\n' "$1"; }

echo "[코드]"
info "HEAD $(git rev-parse --short HEAD) $(git describe --tags --exact-match 2>/dev/null || echo '(태그 없음)')"

echo "[백엔드]"
if curl -s -m 5 -o /dev/null -w '%{http_code}' "$BASE/health" | grep -q 200; then ok "/health 응답"; else bad "백엔드가 응답하지 않음 — 서버를 띄우세요 (docs/chatbot_HANDOVER.md 2.2절)"; fi

echo "[데모 계정]"
if [ -z "${DEMO_PASSWORD:-}" ]; then
  bad "DEMO_PASSWORD 환경변수가 없음"
else
  TOKEN=$(curl -s -m 10 -X POST "$BASE/auth/login" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$DEMO_PASSWORD\"}" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    ok "데모 계정 로그인 ($EMAIL)"
    WEEK=$(curl -s -m 10 "$BASE/users/me/progress" -H "Authorization: Bearer $TOKEN" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin).get("current_week"))' 2>/dev/null)
    [ "$WEEK" = "6" ] && ok "현재 주차 6" || bad "현재 주차가 6이 아님($WEEK) — seed_demo_account.py 를 다시 실행"
    N=$(curl -s -m 10 "$BASE/counseling-sessions?limit=10" -H "Authorization: Bearer $TOKEN" \
      | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d if isinstance(d,list) else d.get("items",d.get("sessions",[]))))' 2>/dev/null)
    [ "${N:-0}" -ge 1 ] && ok "과거 상담 기록 ${N}개" || bad "과거 상담 기록 없음 — seed_demo_account.py 를 다시 실행"
    PV=$(curl -s -m 20 -X POST "$BASE/counseling/respond" -H "Authorization: Bearer $TOKEN" \
      -H 'Content-Type: application/json' \
      -d '{"request_id":"preflight","current_week":5,"conversation":[{"role":"user","text":"안녕"}],"progress":{"stage":"explore"}}' \
      | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("prompt_version") or d.get("detail"))' 2>/dev/null)
    if [ "$PV" = "$EXPECTED_PROMPT" ]; then ok "상담 모델 응답 ($PV, OpenAI 키 정상)"; else bad "상담 모델 응답 이상: $PV — 키 설정과 백엔드 재시작 확인"; fi
  else
    bad "데모 계정 로그인 실패 — 비밀번호 또는 seed 확인"
  fi
fi

echo "[기기]"
DEV=$(adb devices | awk 'NR>1 && $2=="device"{print $1}' | head -1)
if [ -n "$DEV" ]; then
  ok "기기 연결 ($DEV)"
  adb -s "$DEV" reverse tcp:8090 tcp:8090 >/dev/null 2>&1
  adb -s "$DEV" reverse --list | grep -q 'tcp:8090' && ok "포트 포워딩 tcp:8090 (다시 걸었음)" || bad "포트 포워딩 실패"
else
  bad "adb 기기 없음 — 무선 디버깅 재연결 후 다시 실행"
fi

if [ "${1:-}" = "--install" ] && [ -n "$DEV" ]; then
  echo "[데모 빌드 설치]"
  flutter build apk --debug \
    --dart-define=API_BASE_URL=$BASE \
    --dart-define=COUNSELING_REMOTE_REALIZER=true \
    --dart-define=COUNSELING_REMOTE_REALIZER_KILL_SWITCH=false \
    --dart-define=COUNSELING_LLM_LED_PATH=true 2>&1 | tail -1
  adb -s "$DEV" install -r build/app/outputs/flutter-apk/app-debug.apk 2>&1 | tail -1 | grep -q Success \
    && ok "앱 설치 (B 경로 ON)" || bad "앱 설치 실패"
fi

echo
if [ $FAIL -eq 0 ]; then echo "사전 점검 통과. 앱에서 데모 계정으로 로그인하고 앱 내 확인(chatbot_HANDOVER.md 7.2절 4번)으로 넘어가세요."; else echo "실패 항목을 해결한 뒤 다시 실행하세요."; exit 1; fi
