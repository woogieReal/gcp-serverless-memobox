# 단계별 작업 순서

---

## STEP 1. GCP 인프라 세팅 (Terraform)

- [ ] Terraform 설치 확인 (`terraform -v`)
- [ ] `terraform/` 디렉토리 생성 및 `main.tf` 작성
  - GCS 버킷 리소스 정의
  - 서비스 계정(Service Account) 리소스 정의
  - IAM 바인딩 정의
    - `Cloud Functions Developer`
    - `Storage Object Admin` (생성한 버킷 한정)
  - 서비스 계정 JSON 키 리소스 정의 및 로컬 파일 출력
- [ ] `terraform init` — 프로바이더 초기화
- [ ] `terraform plan` — 생성될 리소스 사전 확인
- [ ] `terraform apply` — 인프라 프로비저닝 실행
- [ ] 출력된 JSON 키 파일 확인

---

## STEP 2. GitHub Repository 연동 (콘솔 작업)

- [ ] GitHub Repository에 Environment `Production` 생성
- [ ] `Production` Environment Secrets에 `GCP_SA_KEY` 등록 (발급한 JSON 키 내용)

---

## STEP 3. 프로젝트 초기 세팅 (코드 작업)

- [ ] `package.json` 초기화
- [ ] 의존성 설치
  - `express` — HTTP 라우터
  - `@google-cloud/storage` — GCS 연동
- [ ] 프로젝트 디렉토리 구조 확정 및 엔트리 파일(`index.js`) 생성

---

## STEP 4. 핵심 로직 구현 (코드 작업)

- [ ] IP 화이트리스트 미들웨어 구현
  - `x-forwarded-for` 마지막 값 추출
  - 허용 IP 목록과 비교 → 불일치 시 `403` 반환
- [ ] 파일명 검증 미들웨어 구현
  - 허용 패턴(`^[a-zA-Z0-9_-]+$`) 및 100자 길이 검증 → 위반 시 `400` 반환
- [ ] GCS CRUD 함수 구현
  - 목록 조회 — 버킷 내 파일명 리스트 반환
  - 내용 조회 — 오브젝트 텍스트 스트리밍
  - 생성 — 중복 확인 후 업로드 (중복 시 `409`)
  - 수정 — 존재 확인 후 덮어쓰기 (미존재 시 `404`)
  - 삭제 — 오브젝트 제거 (미존재 시 `404`)
- [ ] Express 라우터 연결 (`/memoApi` 베이스 URI)
- [ ] 에러 응답 형식 통일 (`{ "error": "..." }` JSON)

---

## STEP 5. CI/CD 파이프라인 구성 (코드 작업)

- [ ] `.github/workflows/deploy.yml` 작성
  - 트리거: `main` 브랜치 push
  - 환경: `Production` (Environment Secrets 참조)
  - 인증: `GCP_SA_KEY`로 gcloud 인증
  - 배포: `gcloud functions deploy --gen2` 실행

---

## STEP 6. 배포 및 검증

- [ ] `main` 브랜치 push → GitHub Actions 파이프라인 성공 확인
- [ ] 발급된 HTTPS 엔드포인트 주소 확보
- [ ] 오피스 내부망 PC에서 전체 CRUD 엔드포인트 호출 테스트
- [ ] 외부 IP에서 호출 시 `403` 차단 확인
