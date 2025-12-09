# Mindrium Backend API

FastAPI 기반 백엔드 서버

## 로컬 실행

1. 환경 변수 설정
```bash
cp .env.example .env
# .env 파일을 열어서 실제 값들을 입력하세요
```

2. 의존성 설치
```bash
pip install -r requirements.txt
```

3. 서버 실행
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```

## Render 배포

### 방법 1: render.yaml 사용 (추천)

1. GitHub에 코드 푸시
2. Render 대시보드에서 "New" → "Blueprint"
3. 저장소 연결
4. 환경 변수 설정:
   - `MONGO_URI`: MongoDB 연결 문자열
   - `OPENAI_API_KEY`: OpenAI API 키 (선택)

### 방법 2: 수동 설정

1. GitHub에 코드 푸시
2. Render 대시보드에서 "New" → "Web Service"
3. 저장소 선택
4. 설정:
   - **Root Directory**: `backend/app`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. 환경 변수 추가 (Environment 탭)

## 환경 변수

필수:
- `MONGO_URI`: MongoDB 연결 문자열
- `JWT_SECRET`: JWT 액세스 토큰 시크릿
- `JWT_REFRESH_SECRET`: JWT 리프레시 토큰 시크릿

선택:
- `OPENAI_API_KEY`: OpenAI API 키
- `CORS_ORIGINS`: CORS 허용 도메인 (기본값: *)
- 기타 설정은 `.env.example` 참고

## API 문서

서버 실행 후:
- Swagger UI: http://localhost:8080/docs
- ReDoc: http://localhost:8080/redoc
