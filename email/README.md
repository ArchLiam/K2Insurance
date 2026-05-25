# K2 Insurance — Email Assets (Public CDN)

이 디렉토리는 K2 Insurance Salesforce Org이 발송하는 이메일에서 참조하는 **외부 공개 정적 자산**을 보관합니다. GitHub Pages가 이 디렉토리를 HTTPS로 서빙하며, Salesforce Enhanced Letterhead의 `<img src>`는 본 디렉토리의 URL만 가리킵니다.

> **운영 원칙**: 이 디렉토리에 들어오는 파일은 **외부 수신자(고객사, 보험사) 누구나 볼 수 있다고 간주**하십시오. 내부 자료, PII, 매출 데이터, 미공개 브랜드 가이드는 절대 커밋하지 않습니다.

---

## 1. 호스팅 자산 URL

| Asset | Path | Primary URL (GitHub Pages) | Backup URL (jsDelivr CDN) |
|---|---|---|---|
| Company logo | `email/logo.png` | `https://archliam.github.io/K2Insurance/email/logo.png` | `https://cdn.jsdelivr.net/gh/ArchLiam/K2Insurance@master/email/logo.png` |
| _(향후 추가)_ | | | |
| _(향후 추가)_ | | | |

Primary URL이 일시적으로 장애가 발생하면 jsDelivr가 동일 파일을 동일 경로로 서빙합니다. Letterhead의 `<img src>`는 평시 Primary를 유지하고, 장애 시에만 Backup으로 일괄 교체하십시오.

---

## 2. 로고 교체 절차

### Case A — 동일 로고 미세 수정 (URL 무수정)

1. 신규 이미지 사양을 만족하는지 검증 (아래 §3).
2. 이 디렉토리의 `logo.png`를 **같은 파일명**으로 덮어쓰기.
3. 커밋 메시지 예시: `update email logo (color tweak per K2 brand guide v2)`.
4. Push → GitHub Pages 자동 재배포 (보통 1–2분 내 반영).
5. 캐시 강제 무효화가 필요하면 §4 캐시 버스팅 참고.

### Case B — 대대적 리브랜딩 (이력 보존 + 즉시 전환)

1. 기존 `logo.png`를 `logo-YYYY.png` 형태로 **사본 복제** (예: `logo-2026.png`).
2. 신규 로고를 `logo.png`로 덮어쓰기.
3. 커밋 메시지에 변경 배경 명시.
4. Push 후 Pages 빌드 완료 확인.
5. Salesforce 측 Letterhead URL은 무수정 — 동일 파일명을 계속 가리키므로 자동 반영됩니다.

> **버전 사본**의 목적은 시각적 이력 보존 + 회귀 시 즉시 롤백입니다. Letterhead가 이를 직접 참조하지는 않습니다.

---

## 3. 이미지 사양 (필수 준수)

| 항목 | 요구 사양 |
|---|---|
| Format | **PNG** (transparent background 권장) |
| 권장 해상도 | **400×400 이상** (현재 K2 로고: 400×395 정사각형). 가로형 로고 사용 시 400×120 또는 600×180 |
| 최대 파일 크기 | **100KB 이하** (현재 28KB) |
| Color profile | sRGB |
| **금지 포맷** | **SVG** — Outlook/Gmail 등 주요 이메일 클라이언트 미지원 |
| 금지 사항 | EXIF 메타데이터, 외부 폰트 의존, 애니메이션 GIF |

해상도가 너무 크면 일부 클라이언트가 다운샘플 시 흐려지고, 너무 작으면 Retina 화면에서 픽셀이 깨집니다. **2× 디스플레이 대응**으로 표시 의도 크기의 약 2배를 권장하며, 이메일 헤더 실제 표시 크기는 Letterhead HTML의 `<img width="...">` 속성으로 제어하십시오 (예: `width="140"`).

---

## 4. 캐시 버스팅 (수신자 측 이메일 클라이언트 캐시 우회)

이메일 클라이언트와 중간 프록시는 동일 URL의 이미지를 적극적으로 캐시합니다. 로고를 교체했는데 일부 사용자에게 구버전이 계속 보이면 두 가지 전략 중 하나를 적용합니다.

### Strategy 1 — 파일명 자체 변경 (권장)

- `logo.png` → `logo-v2.png`로 신규 파일 추가, Letterhead의 `<img src>`도 동시 갱신.
- 장점: URL이 완전히 달라 모든 캐시를 강제 우회.
- 단점: Letterhead HTML 수정 필요 (1회).

### Strategy 2 — 쿼리스트링 부착

- Letterhead 측: `https://archliam.github.io/K2Insurance/email/logo.png?v=2026-10-01`
- 장점: 파일 자체는 동일, URL만 변형.
- 단점: 일부 보수적인 이메일 클라이언트는 쿼리스트링을 무시하고 캐시 — 100% 보장 안 됨.

> **결론**: 주요 리브랜딩 시 Strategy 1, 미세 수정 시 Strategy 2.

---

## 5. Custom Domain 전환 (향후)

`archliam.github.io` 서브경로 대신 `cdn.k2insurance.com` 등 자체 도메인으로 전환할 경우의 절차입니다.

1. K2 도메인 DNS 관리자에서 CNAME 레코드 추가:
   - Name: `cdn` (또는 원하는 서브도메인)
   - Type: `CNAME`
   - Value: `archliam.github.io`
2. GitHub → Repo → Settings → Pages → **Custom domain**에 `cdn.k2insurance.com` 입력 → Save.
3. **Enforce HTTPS** 체크 (DNS 전파 후 활성화 가능).
4. 모든 Salesforce Letterhead의 `<img src>`를 신규 도메인으로 일괄 치환.
5. 구 URL은 최소 90일간 유지 (이미 발송된 이메일이 참조 중일 수 있음 — GitHub Pages는 기존 URL을 계속 서빙하므로 별도 조치 불요).

> Custom Domain 전환 후에도 jsDelivr 백업 URL은 `ArchLiam/K2Insurance@master` 경로로 그대로 동작합니다.

---

## 6. Salesforce 측 사용처

| 사용처 | Letterhead 이름 | 최종 갱신 |
|---|---|---|
| Production | _(추후 기입)_ | _(추후 기입)_ |
| Sandbox | _(추후 기입)_ | _(추후 기입)_ |

Letterhead HTML 내 `<img src>` 값을 변경했다면 위 표 갱신을 잊지 마십시오.

---

## 7. 변경 이력

| Date | Change | Operator |
|---|---|---|
| 2026-05-25 | 디렉토리 신설, placeholder logo.png 배치 | 5S Infusion |
| 2026-05-25 | 실제 K2 로고로 교체 (400×395, 28KB, Static Resource `K2_Logo_png`와 동일 원본) | 5S Infusion |

---

*이 디렉토리의 변경은 모두 K2 외부 이메일 수신자에게 즉시 노출됩니다. 커밋 전 반드시 self-review 하십시오.*
