# 환경변수 및 시크릿 관리 방식

## 핵심 원칙

> 민감한 값(키, 비밀번호 등)은 코드에 절대 포함하지 않는다.

---

## 이 프로젝트의 시크릿 목록

| 시크릿 | 내용 | 관리 위치 |
|--------|------|-----------|
| `GCP_SA_KEY` | GCP 서비스 계정 JSON 키 | GitHub Environment Secrets |
| `terraform/sa-key.json` | 위와 동일한 키의 로컬 파일 | 로컬 전용 (gitignore 처리) |

---

## 환경별 관리 방식

### 로컬 개발 환경

`terraform apply` 실행 시 `terraform/sa-key.json`이 자동 생성된다.
이 파일은 `.gitignore`에 등록되어 있어 git에 커밋되지 않는다.

```
# .gitignore
terraform/sa-key.json
```

### CI/CD 환경 (GitHub Actions)

로컬의 `sa-key.json`을 GitHub **Environment Secrets**에 등록해 사용한다.

```
로컬 sa-key.json 내용 복사
    ↓
GitHub → Settings → Environments → Production
    → Add secret → GCP_SA_KEY
    ↓
GitHub Actions 워크플로우에서 ${{ secrets.GCP_SA_KEY }} 로 참조
```

---

## Repository Secrets vs Environment Secrets

| 구분 | Repository Secrets | Environment Secrets |
|------|--------------------|---------------------|
| 접근 범위 | 모든 워크플로우 | 특정 Environment를 명시한 워크플로우만 |
| 보안 수준 | 낮음 | 높음 |
| 이 프로젝트 선택 | | ✅ Production Environment |

Environment Secrets를 사용하면 워크플로우에 `environment: Production`이 명시된 경우에만 Secret에 접근할 수 있어 노출 범위를 제한할 수 있다.

---

## 관련 파일

- `terraform/main.tf` — `sa-key.json` 생성 리소스 정의
- `.gitignore` — `sa-key.json` 등 민감 파일 추적 제외
- `.github/workflows/deploy.yml` — `secrets.GCP_SA_KEY` 참조 (STEP 3에서 작성)
