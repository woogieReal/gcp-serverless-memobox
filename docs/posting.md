# GCP로 서버리스 메모 API 만들기

## 만든 이유

- 회사에서 테스트 기기 간 간단한 텍스트를 공유할 일이 자주 있음
- 공용으로 사용하는 테스트 기기라 메신저나 클라우드 로그인을 하기는 애매함.
- 어차피 GCP를 써볼 기회가 필요했고, 이 참에 직접 만들어보기로 함
- 목표: 최대한 단순하게, 인프라도 코드로 관리

## 사용한 GCP 서비스

**Cloud Functions Gen 2**
- HTTP 요청을 받아 코드를 실행하는 서버리스 컴퓨팅 서비스
- 서버를 직접 관리할 필요 없이 함수 단위로 배포
- Gen 2는 내부적으로 Cloud Run 위에서 동작해 콜드 스타트가 빠르고 요청 동시성 처리가 개선됨

**Cloud Storage (GCS)**
- GCP의 오브젝트 스토리지 서비스
- DB 없이 텍스트 파일을 `{filename}.txt` 형태로 버킷에 저장하는 방식으로 사용
- 단순 메모 저장 용도로는 DB보다 오히려 설정이 적어서 적합

**Cloud Run / Cloud Build / Artifact Registry**
- Cloud Functions Gen 2 배포 시 내부적으로 자동으로 사용되는 서비스들
- Cloud Build: 소스 빌드, Artifact Registry: 컨테이너 이미지 저장, Cloud Run: 실제 실행 환경
- 직접 조작하지 않지만 각 API를 활성화해야 배포가 됨

**IAM / Service Account**
- GCP 리소스에 대한 권한 관리 시스템
- GitHub Actions가 GCP에 배포할 때 사용하는 전용 계정(Service Account)을 만들고 최소 권한만 부여
- 부여한 권한: `cloudfunctions.developer`, `run.admin`, `storage.objectAdmin` (버킷 한정), `iam.serviceAccountUser`

## 아키텍처

```
Client
  → Cloud Functions Gen 2 (HTTPS, 인증 없음)
    → IP 화이트리스트 미들웨어
      → Express 라우터
        → Google Cloud Storage
```

## 인증 방식: 로그인 대신 IP 화이트리스트

- 별도 로그인을 만들지 않은 이유: 나 혼자 쓰는 내부 도구에 OAuth나 JWT는 과함
- IP 화이트리스트를 선택한 이유
  - 회사 오피스 IP는 고정 IP라 관리가 쉬움
  - 구현이 단순하고 의존성이 없음
- 구현 방식
  - 환경변수 `ALLOWED_IPS`에 허용 IP를 쉼표로 구분해서 주입
  - `x-forwarded-for` 헤더의 마지막 값을 실제 클라이언트 IP로 판단 (앞쪽 값은 스푸핑 가능)
  - 비허용 IP는 403 반환

## Terraform으로 인프라 관리

- Terraform을 쓴 이유: GCP 콘솔에서 클릭으로 만들면 재현이 안 됨
- 관리하는 리소스
  - GCS 버킷
  - Service Account 및 IAM 바인딩
  - 필요한 GCP API 활성화 (5개)
  - Service Account JSON 키 로컬 출력 (`sa-key.json`)
- `terraform apply` 한 번으로 전체 인프라가 올라옴

## CI/CD: GitHub Actions + Service Account 키

흐름:

1. `main` 브랜치에 push
2. GitHub Actions 실행
3. `GCP_SA_KEY` (Service Account JSON 키)로 GCP 인증
4. `gcloud functions deploy` 실행
5. 배포 시 `ALLOWED_IPS`, `BUCKET_NAME` 환경변수 주입

키 관리:
- `sa-key.json`은 `.gitignore`에 추가해 저장소에 올라가지 않게 처리
- GitHub `Production` Environment Secrets에 저장해 파이프라인에서만 참조

## 삽질 기록

**GCP API 비활성화 오류**
- Cloud Functions만 켜면 될 줄 알았는데, Gen 2 배포에는 Cloud Build, Cloud Run, Artifact Registry, Cloud Resource Manager API도 필요했음
- 에러 메시지를 보고 하나씩 Terraform에 추가해서 해결

**IAM 권한 부족 오류 두 가지**
- `iam.serviceaccounts.actAs` 오류: Cloud Functions이 기본 컴퓨트 서비스 계정을 사용할 때 필요한 권한. `roles/iam.serviceAccountUser`를 컴퓨트 서비스 계정에 바인딩해서 해결
- `run.services.setIamPolicy` 오류: `--allow-unauthenticated` 옵션 적용 시 Cloud Run IAM 정책을 수정하는 권한이 필요. `roles/run.admin`을 프로젝트 레벨로 부여해서 해결
- 둘 다 Terraform으로 추가해서 재현 가능하게 관리

**URL 경로 중복**
- 배포 후 API URL이 `.../memoApi/memoApi/`로 `memoApi`가 두 번 나오는 문제
- Cloud Functions Gen 2는 함수 이름 prefix를 Express에 전달하기 전에 제거함. Express 라우터를 `/memoApi`에 마운트해두니 클라이언트가 `memoApi`를 두 번 써야 하는 구조가 됨
- Express 마운트 경로를 `/`로 바꿔서 해결

## 마무리

- 만들고 나니 실제로 잘 쓰고 있음
- GCP 서비스 간 의존 관계나 IAM 권한 구조를 직접 부딪히며 익힌 게 생각보다 많았음
- Terraform 덕분에 인프라를 날리고 다시 세워도 명령어 몇 줄로 복원 가능한 게 제일 마음에 듦

저장소: https://github.com/woogieReal/gcp-serverless-memobox
