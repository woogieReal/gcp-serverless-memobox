# gcp-serverless-memobox

Cloud Functions Gen 2 + GCS 기반 서버리스 메모 CRUD API

## 기술 스택

- Runtime: Node.js 22, Express
- Storage: Google Cloud Storage
- Infra: Cloud Functions Gen 2, Terraform
- CI/CD: GitHub Actions

## 아키텍처

```
Client
  → Cloud Functions Gen 2 (HTTPS trigger)
    → IP 화이트리스트 미들웨어 (x-forwarded-for 검증)
      → Express 라우터
        → Google Cloud Storage
```

- IP 화이트리스트: 환경변수 `ALLOWED_IPS` (쉼표 구분)로 관리, 비허용 IP는 403 반환
- 데이터 저장: GCS 버킷에 `{filename}.txt` 형태로 저장

## API

Base URL: `https://asia-northeast3-woogie-sandbox-gcp.cloudfunctions.net/memoApi`

| Method | Path | 설명 | 성공 응답 |
|--------|------|------|-----------|
| GET | `/` | 메모 목록 조회 | 200 |
| POST | `/` | 메모 생성 | 201 |
| GET | `/:filename` | 메모 내용 조회 | 200 |
| PUT | `/:filename` | 메모 수정 | 200 |
| DELETE | `/:filename` | 메모 삭제 | 204 |

**요청 바디 (POST / PUT)**

```json
{ "filename": "my-memo", "content": "내용" }
```

**파일명 규칙**: 영문자, 숫자, `-`, `_` 만 허용 / 최대 100자

## 에러 응답

| 상태 코드 | 의미 |
|-----------|------|
| 400 | 파일명 누락 또는 패턴 위반 |
| 403 | 허용되지 않은 IP |
| 404 | 파일 없음 |
| 409 | 파일명 중복 (POST) |
| 500 | 서버 오류 |

에러 응답 형식: `{ "error": "..." }`

## 인프라 설정 (Terraform)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

생성 리소스: GCS 버킷, 서비스 계정, IAM 바인딩, GCP API 활성화

## CI/CD

`main` 브랜치 push 시 GitHub Actions가 자동 배포.

GitHub `Production` Environment Secrets 필요:

| Secret | 내용 |
|--------|------|
| `GCP_SA_KEY` | 서비스 계정 JSON 키 |
| `ALLOWED_IPS` | 허용 IP 목록 (쉼표 구분) |

## 테스트

```bash
bash scripts/test-api.sh
```

정상 시나리오 7개 + 예외 시나리오 5개, 총 12개 케이스 자동 검증
