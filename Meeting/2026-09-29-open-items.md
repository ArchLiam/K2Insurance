# 9월 미팅 후속 작업 현황 — 2026-09-29

대상은 [9월 12일 회의](2026-09-12.md)와 [9월 28일 회의](2026-09-28.md)입니다. 회의 당시 체크박스는 그대로 두고, 이후 구현·배포 기록 및 이번 운영 조회를 대조했습니다. 과거 회의의 모든 이월 항목을 재감사한 문서는 아닙니다.

## 남은 작업

| 항목 | 현재 상태 | 다음 작업 | 출처 |
| --- | --- | --- | --- |
| 커미션 리포트 기간 기준 통일 | 일부 반영. 운영 Agent 커미션 리포트 4개는 아직 Commission Date로 기간 제한 | 사용할 리포트를 정하고 Payment Period 기준으로 맞춘 뒤 Agent Management와 대상·합계 대조 | 9/12 C1 |
| 리포트의 올바른 필드 안내 | 필드 정의 확인 완료. 9/28에서 말한 문제 리포트·열은 아직 특정되지 않음 | 운영 담당자가 문제 리포트와 열을 확인하면 정확한 필드·선택 방법 안내 | 9/28 A1 |
| 기존 Insurance·Open Renewal의 Company 연결 보완 | 기존 데이터 일괄 보정 미진행 | 누락·불일치 대상을 정하고 올바른 회사 연결을 확인한 후 보정 | 9/12 A4, 후속 설계 2-C |
| Agent Payout 전용 이메일 버튼 | PDF 생성·저장·미리보기와 이메일 템플릿은 완료. 현재 수신자 지정·PDF 첨부는 수동 | 버튼에서 해당 Agent 수신자와 최신 PDF를 지정하는 기능이 필요하면 후속 구현. 실제 전달 검증도 미실행 | 9/28 A3 |
| 외부 기업 리드폼 회사 정보 | 내부 Lead·전환은 완료, 외부 폼은 미반영 | 외부 폼의 회사 주소·EIN·SIC 등 입력 범위와 일정 결정 | 9/28 C1 |
| Insurance 이메일의 추가 Contact 정보 | 조건부 요청이며 필요한 항목 미확정 | 운영 담당자가 필요한 항목 전달 후 참조 필드·Merge 방식 검토 | 9/28 A2 |

전용 이메일 버튼, 외부 기업 리드폼, 추가 Contact 필드는 이 현황 정리에서 새로 구현하거나 범위를 확정하지 않았습니다. 현재 템플릿과 수동 PDF 첨부로 Payout 이메일을 작성할 수 있습니다.

## 이번 운영 조회로 확인한 리포트 상태

K2 Insurance 운영 Org의 Report/Analytics 설정만 조회했습니다. 리포트 실행 결과·고객 상세·지급 금액을 내보내거나 필터를 변경하지 않았습니다.

| 리포트 | 저장된 기간 조건 |
| --- | --- |
| `Commission By Agent` | Commission Date — 이전 회계 분기 |
| `Copy of Commission By Agent` | Commission Date — 이전 회계 분기 |
| `Commission_26_Quartely By Agent` | Commission Date — 이전 회계 분기 |
| `Biannual Commission By Agent` | Commission Date — 사용자 지정 반기 |
| `Spec Agent Commission Report` | Payment Period 필터 사용, Commission Date 기간 제한 없음 |
| `Commission_26_회사,손님,월단위 정리` | Payment Period 필터 사용, 생성일 기간 제한 없음 |

`Commission_Line__c.Payment_Period__c`는 운영 describe에서 `calculated=true`이고 수식은 `Commission_Statement__r.Payment_Period__c`입니다. 즉 **반환 형식이 Text인 Formula**입니다. 부모 `Commission_Statement__c.Payment_Period__c`는 입력 가능한 일반 Text입니다. Text라는 표시만으로 잘못된 필드라고 판단하지 않습니다. 9/28의 숫자 불일치가 이 필드를 말한 것인지는 확인되지 않았습니다.

`Commission_Line__c.Paid_Out__c`도 운영에서 `NOT(ISBLANK(Payout__c))` 형태의 Formula Checkbox임을 확인했습니다. 새 지급 여부 필드는 필요하지 않습니다.

## 완료된 개발과 남은 사용자 확인

| 개발 결과 | 남은 확인 |
| --- | --- |
| [Commercial·Group Health Lead 회사 정보 및 Flow 전환](2026-09-12-lead-company-flow.md): 운영 배포·활성화 완료 | 일반 사용자 화면에서 회사/개인 주소 분리, 파일·가족 관계 전환 최종 확인 |
| [Agent Payout PDF](2026-09-29-agent-payout-pdf.md): 운영 생성·Files 저장·최신 버전 미리보기 확인 | Kay가 지급 문의에 필요한 상세가 충분한지 확인 |
| [Agent Payout 이메일 템플릿](2026-09-29-agent-payout-email.md): 운영 생성, 실제 값 치환·화면 확인 | 해당 Agent 수신자·최신 PDF를 수동 지정한 뒤 실제 발송/수신 확인 |
| [Insurance Company 및 Renewal 회사 연결](2026-09-12-insurance-company-design.md): 문서상 운영 배포 및 개발 검증 완료 | 일반 사용자 UI, 다음 정기 자동 생성, 기존 누락 Renewal 사례 재확인 |
| Group Health 갱신 이메일: 기존 Quote 기반 구현 및 렌더링 검증 이력 있음 | Kay가 회사명·Carrier·새 Quote 조건 확인, Quote → Closed Won → 새 Insurance 전체 과정 확인 |
| Group Health Policy Number 입력 | 후속 설계 문서에 사용자 검증 완료가 기록돼 있어 미구현 목록에서 제외 |

이번 작업에서는 위 전체 업무 흐름을 다시 실행하지 않았습니다. 특히 관리자/렌더링 검증과 일반 사용자 UI·실제 이메일 수신 검증을 구분합니다.

## 저장소 반영

- 기존 미푸시 Lead 전환 커밋과 PDF·이메일 템플릿 변경을 함께 커밋·푸시하는 범위입니다.
- 사용자가 추가로 저장한 운영 `Lightning_Agent_Payout_Record_Page`의 Related/Activity 탭과 Agent Payout Layout을 임시 프로젝트에서 조회·비교한 뒤 소스에 반영했습니다. 운영에 재배포하지 않았습니다.
- 고객 PDF, 커미션 원본, 인증 파일 및 조회 결과의 개인별 필터 값은 커밋에 포함하지 않습니다.
