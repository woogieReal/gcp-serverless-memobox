# GCP 서비스 계정 (Service Account)

## 한 줄 요약

> GitHub Actions 같은 자동화 시스템이 GCP에 로그인할 때 쓰는 전용 계정

---

## 왜 필요한가?

GCP에 접근하려면 원래 구글 계정으로 로그인해야 한다. 그런데 GitHub Actions는 사람이 아닌 자동화 시스템이라 구글 계정으로 로그인할 수 없다. 이럴 때 사용하는 것이 서비스 계정이다.

서비스 계정은 사람 대신 **애플리케이션이나 자동화 시스템**이 GCP API를 호출할 수 있도록 만든 계정이다.

---

## 이 프로젝트에서의 흐름

```
GitHub Actions가 실행됨
       ↓
memobox-github-actions 서비스 계정으로 GCP 인증
       ↓
부여된 권한 범위 내에서만 GCP 조작 가능
  - Cloud Functions 배포 (Cloud Functions Developer)
  - GCS 버킷 접근 (Storage Object Admin)
```

---

## 서비스 계정 키 (google_service_account_key)

서비스 계정을 만드는 것과 그 계정의 키를 발급하는 것은 별개의 작업이다. 사람으로 비유하면 이렇다.

```
google_service_account      →  직원 채용 (계정 생성)
google_service_account_key  →  사원증 발급 (인증 키 생성)
```

이 리소스가 실행되면 GCP가 RSA 2048 비트 키쌍을 생성하고, `private_key` 값(base64 인코딩된 JSON)을 반환한다. 그 다음 `local_file` 리소스가 이를 디코딩해서 `sa-key.json`으로 저장한다.

```
google_service_account_key 실행
    ↓
GCP가 RSA 키쌍 생성 후 private_key 반환 (base64)
    ↓
local_file이 base64decode() 후 sa-key.json으로 저장
```

---

## sa-key.json은 어떻게 쓰이나?

`sa-key.json`은 서비스 계정의 비밀번호 역할을 하는 파일이다. 파일 자체는 보안상 git에 커밋하지 않고, 아래 흐름으로 GitHub Actions에서 사용한다.

```
terraform apply
    ↓
sa-key.json 로컬 생성
    ↓
개발자가 파일 내용을 복사해서
GitHub Environment Secrets에 GCP_SA_KEY로 등록
    ↓
GitHub Actions 실행 시
secrets.GCP_SA_KEY 값을 꺼내서 gcloud 인증에 사용
```

GitHub Secrets는 암호화되어 저장되고 워크플로우 로그에도 노출되지 않는다.

---

## 관련 파일

- `terraform/main.tf` — 서비스 계정 및 IAM 바인딩 리소스 정의
- `terraform/sa-key.json` — 로컬 전용 키 파일 (gitignore 처리)
