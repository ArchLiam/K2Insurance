# 🔄 K2 Insurance — Renewal 시스템 안내

**작성일**: 2026-05-16 | **담당**: Liam Jeong

---

## 무엇이 바뀌었나

Salesforce에 **자동 리뉴얼 추적 시스템**을 구축했습니다. 폴리시 만료 60일 전에 시스템이 자동으로 Renewal을 생성하고 Kay Kim에게 알림이 갑니다.

- **Renewal** 파이프라인: Renewal Identified → Quote Requested → Closed Won/Lost (7단계)
- **Quote** 비교: 여러 Provider 견적을 한 자리에서 비교, 고객 선택 시 자동으로 새 Insurance 생성
- **자동화 Flow 3개**: 60일 알림 / Closed Won → 새 Insurance / 만료 폴리시 Inactive 처리

---

## ⚠️ 결정 필요 사항 3가지

### 1️⃣ 만료된 Active 폴리시 **127건** 처리 동의
End Date 지났는데 Status가 Active로 남아있음 (2007년 ~ 2026-05). 자동 Inactive 처리할까요?

### 2️⃣ End Date 비어있는 폴리시 **96건**
Start Date 또는 Term이 비어있어 만료일 계산 불가. 데이터 백필 vs Disqualified 처리?

### 3️⃣ 2027-01-01 만료 **450건** — 진위 확인 ⚠️
한 날짜에 450건이 몰림 → 데이터 import 시 placeholder로 의심. 진짜 만료일이 아니면 11월부터 무의미한 Renewal 폭주.

---

## 데이터 현황

| 구분 | 건수 |
|---|---|
| 전체 Active | 855 |
| 미래 만료 (1년 안) | 611 |
| └ 2026-05~12 | 120 |
| └ 2027-01-01 ⚠️ | 450 |
| └ 2027-02~05 | 41 |
| 이미 만료 | 127 |
| End Date 없음 | 96 |

**Flow 활성화 시 월별 Renewal 생성 예측**:
6월 9건 · 7월 20건 · 8월 13건 · 9월 20건 · 10월 12건 · 11월 14건 · 12월 30건 · **2027년 1월 450건** ⚠️ · 그 후 월 4~17건

---

*문의: liam.jeong@5sinfusion.com*
