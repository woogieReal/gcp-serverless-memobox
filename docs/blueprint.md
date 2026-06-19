# GCS 기반 초간단 메모 CRUD 시스템 및 CI/CD 구축 기획서
### Cloud Functions와 GitHub Actions를 활용한 오피스 내선 전용 서버리스 아키텍처

---

## 1. 기획 개요
본 프로젝트는 별도의 데이터베이스 인프라 구축 비용 및 관리 공수를 최소화하고, 회사(오피스) 내부망 환경에서 안전하고 편리하게 텍스트 형태의 메모를 관리할 수 있는 서버리스 백엔드 시스템 구축을 목표로 한다. 개발 편의성을 극대화하기 위해 무거운 키 인증 대신 IP 화이트리스트 형식을 채택하며, GitHub Actions를 통해 지속적 통합 및 배포(CI/CD) 파이프라인을 자동화한다.

---

## 2. 핵심 통제 및 아키텍처 전략

### 2.1. 단일 엔드포인트 통합 라우팅
* **현황 및 문제점:** Cloud Functions 배포 시 개별 함수마다 독립적인 URI가 생성되어, 5개의 CRUD 기능을 각기 분리할 경우 클라이언트 측 주소 관리가 번거로워짐.
* **해결 방안:** 단일 Cloud Functions 내부에 경량 웹 프레임워크(Express) 라우터를 탑재하여 하나의 베이스 URI(`/memoApi`) 하위에서 모든 HTTP Method를 분기 처리함.

### 2.2. GCS 기반 서버리스 데이터 저장
* **구조:** RDB 또는 NoSQL 데이터베이스를 연동하는 대신, Google Cloud Storage(GCS) 오퍼레이션을 직접 호출하여 파일 생성/수정/삭제를 수행함.
* **메커니즘:** 생성 및 수정 요청 발생 시 버킷 내 `{파일명}.txt` 오브젝트로 텍스트 스트림을 직접 저장 및 오버라이트하며, 조회 및 삭제 요청 시 해당 오브젝트를 즉시 파싱하거나 제거함.

### 2.3. IP 화이트리스트 기반 접근 통제
* **보안 정책:** URL 파라미터나 쿼리스트링에 API Key를 노출하는 방식의 취약점을 보완하기 위해 인프라 진입 단계 및 코드 레벨 미들웨어에서 원격지 IP를 검증함.
* **구현 방식:** 구글 인프라가 HTTP 요청 전달 시 제공하는 프록시 헤더(`x-forwarded-for`)를 추출하여, 사전에 등록된 회사 내부 공인 IP 대역과 일치하지 않을 경우 `403 Forbidden`을 즉시 리턴함.
* **스푸핑 방지:** `x-forwarded-for` 헤더는 클라이언트가 임의로 값을 주입할 수 있으므로, 헤더에 쉼표로 구분된 IP 목록 중 **마지막 값**만 신뢰 소스로 사용한다. 마지막 값은 GCP 프록시가 직접 추가한 것으로 클라이언트가 조작할 수 없다. (예: `x-forwarded-for: <클라이언트_조작값>, <GCP_프록시_추가값>` → 마지막 값만 검증)

### 2.4. 파일명 입력 검증
* **검증 방식:** 화이트리스트 정규식 기반으로, 허용된 문자 이외의 값이 포함된 경우 즉시 `400 Bad Request`를 반환함.
* **허용 패턴:** `^[a-zA-Z0-9_-]+$` (영문 대소문자, 숫자, 언더스코어, 하이픈만 허용)
* **최대 길이:** 100자 초과 시 `400 Bad Request` 반환
* **적용 범위:** `filename`을 입력받는 모든 엔드포인트 (`POST /memoApi/` 의 Request Body, `GET|PUT|DELETE /memoApi/:filename` 의 경로 파라미터)

---

## 3. 엔드포인트 URI 상세 설계

| 기능 정의 | HTTP 메서드 | URI 엔드포인트 | 동작 및 명세 개요 |
| :--- | :--- | :--- | :--- |
| **메모 목록 조회** | `GET` | `/memoApi/` | 지정된 GCS 버킷 내부의 모든 파일명 리스트를 배열 형태로 반환 |
| **메모 내용 조회** | `GET` | `/memoApi/:filename` | 특정 파일명을 타겟팅하여 해당 텍스트 본문 내용을 그대로 스트리밍 |
| **신규 메모 생성** | `POST` | `/memoApi/` | JSON Body로 `filename`과 `content`를 수신하여 GCS에 신규 업로드. 동일 `filename`이 이미 존재할 경우 `409 Conflict` 반환 (수정은 `PUT` 사용) |
| **기존 메모 수정** | `PUT` | `/memoApi/:filename` | 해당 파일의 존재 여부를 1차 검증한 후, 전달받은 본문으로 덮어쓰기 수행 |
| **특정 메모 삭제** | `DELETE` | `/memoApi/:filename` | 버킷 내에서 일치하는 오브젝트를 완전히 삭제 처리 |

---

## 4. 에러 응답 명세

모든 에러 응답은 JSON 형태로 통일하며, `error` 필드에 사유를 포함한다.
```json
{ "error": "<사유 메시지>" }
```

| HTTP 상태 코드 | 발생 조건 | 적용 엔드포인트 |
| :--- | :--- | :--- |
| `400 Bad Request` | `filename`이 허용 패턴(`^[a-zA-Z0-9_-]+$`) 위반 또는 100자 초과 | `POST /memoApi/`, `GET|PUT|DELETE /memoApi/:filename` |
| `400 Bad Request` | Request Body에 `filename` 또는 `content` 필드 누락 | `POST /memoApi/`, `PUT /memoApi/:filename` |
| `403 Forbidden` | 요청 IP가 화이트리스트에 미등록 | 전체 엔드포인트 |
| `404 Not Found` | 대상 파일이 GCS 버킷에 존재하지 않음 | `GET /memoApi/:filename`, `PUT /memoApi/:filename`, `DELETE /memoApi/:filename` |
| `409 Conflict` | 동일 `filename`의 파일이 이미 존재함 | `POST /memoApi/` |
| `500 Internal Server Error` | GCS 오퍼레이션 실패 등 서버 내부 오류 | 전체 엔드포인트 |

---

## 5. GitHub Actions CI/CD 파이프라인 설계
코드 관리의 영속성과 배포 자동화를 위해 GitHub 릴리스 파이프라인을 연동한다. 개발자가 로컬 검증 후 `main` 브랜치에 코드를 머지하거나 직접 푸시하는 이벤트를 기점으로 자동 배포가 트리거된다.

> **자동화 파이프라인 흐름 (Workflow):**
> 코드 Push/Merge 감지 (GitHub) ➔ 가상 환경 실행 (Ubuntu-Latest) ➔ 소스 코드 체크아웃 ➔ GCP 서비스 계정 키(JSON) 인증 가동 ➔ `gcloud functions deploy` 원격 실행 ➔ 빌드 및 공인 HTTPS URI 갱신 완료

---

## 6. 최종 단계별 구축 로드맵
1. **[1단계] GCP IAM 인프라 세팅:** GitHub Actions가 무중단 접근할 수 있도록 GCP 서비스 계정(Service Account)을 생성하고 비밀키를 발급한다. 권한은 최소 권한 원칙에 따라 `Cloud Functions Developer`와 특정 버킷에 한정된 `Storage Object Admin` 두 가지만 부여한다. 발급된 JSON 키는 GitHub Repository Secrets가 아닌 **Environment Secrets(Production)**에 등록하여 노출 범위를 제한하며, 키는 주기적으로 로테이션한다.
2. **[2단계] GitHub Repository 연동:** 생성된 GCP JSON 키를 깃허브 저장소의 보안 변수(Secrets)에 `GCP_SA_KEY`라는 이름으로 은닉 등록
3. **[3단계] CI/CD 스크립트 배치:** 소스 루트 경로에 `.github/workflows/deploy.yml` 파일을 배치하여 배포 환경 설정 및 런타임 최적화 명세 선언. Cloud Functions 세대는 **Gen 2**를 사용하며 `gcloud functions deploy` 명령어에 `--gen2` 플래그를 명시한다.
4. **[4단계] 최초 파이프라인 구동 및 검증:** `main` 브랜치 반영을 통한 GitHub Actions 초록 불(Success) 확인 및 발급된 HTTPS 주소 확보
5. **[5단계] 회사망 최종 통합 테스트:** 지정된 오피스 IP 대역 내 PC/모바일 기기에서 통합 엔드포인트를 호출하여 차단 및 정상 CRUD 작동 여부를 전수 검증