# 9월 미팅 후속 작업 현황 — 2026-10-02 갱신

대상은 [9월 12일 회의](2026-09-12.md)와 [9월 28일 회의](2026-09-28.md)입니다. 회의 당시 체크박스는 그대로 두고, 이후 구현·배포 기록 및 이번 운영 조회를 대조했습니다. 과거 회의의 모든 이월 항목을 재감사한 문서는 아닙니다.

## 남은 작업

| 항목 | 현재 상태 | 다음 작업 | 출처 |
| --- | --- | --- | --- |
| 리포트의 올바른 필드 안내 | 제공된 불일치 사례는 지급월 기준 문제로 확인했고 관련 리포트 5개 수정 완료. 9/28의 모든 문제 리포트가 같은 원인인지는 미확정 | 기간 필터는 Payment Period Date, 월 표시는 Payment Period 사용. 다른 사례가 있으면 해당 리포트·열 확인 | 9/28 A1 |
| 기존 Insurance·Open Renewal의 Company 연결 보완 | 기존 데이터 일괄 보정 미진행 | 누락·불일치 대상을 정하고 올바른 회사 연결을 확인한 후 보정 | 9/12 A4, 후속 설계 2-C |
| 외부 기업 리드폼 회사 정보 | 내부 Lead·전환은 완료, 외부 폼은 미반영 | 외부 폼의 회사 주소·EIN·SIC 등 입력 범위와 일정 결정 | 9/28 C1 |
| Insurance 이메일의 추가 Contact 정보 | 9/30 사용자 요청으로 착수. 필요한 항목·대상 템플릿 확인 중 | 기존 Policy Holder 연결과 이메일 Merge 방식 조사 후 필요한 정보 보완 | 9/28 A2 |

9/30 사용자가 Agent Payout 전용 이메일 버튼은 필요 없다고 확인하여 남은 작업에서 제외했습니다. 현재 이메일 템플릿과 수동 PDF 첨부 방식을 유지합니다. 외부 기업 리드폼과 추가 Contact 필드의 구체적인 항목은 아직 확정하지 않았습니다.

### 9/30 Insurance 이메일 사전 확인

- 운영 describe에서 `Insurance__c.Policy_Holder__c`가 Contact Lookup이고 관계 이름은 `Policy_Holder__r`임을 확인했습니다. 보험 객체에는 계약자 생년월일·한국 이름·연락처 등을 가져오는 기존 수식 필드가 없습니다.
- 운영 `ACA #3 _개인 건강보험 가입 완료 안내`는 Related Entity Type이 `Insurance__c`인 Lightning HML 템플릿이며 현재 Merge Field는 `{{{Recipient.Name}}}`입니다. 이번 요청의 적용 후보이며, 대상 템플릿과 추가할 Contact 항목은 사용자에게 확인 중입니다.
- 수신자 이름과 보험 계약자 정보를 구분합니다. [Salesforce 공식 안내](https://help.salesforce.com/s/articleView?id=sf.merge_fields_email_templates.htm&language=en_US&type=5)에 따르면 Email Composer의 Recipient Merge Field는 To의 첫 수신자 정보를 사용합니다. 수신자와 무관하게 항상 보험 계약자 정보를 표시해야 한다면 Policy Holder 참조를 기준으로 설계합니다.
- 기존 필드·템플릿을 읽기 전용으로 조사했고, 이 항목의 새 필드 생성·템플릿 변경·배포·이메일 발송은 아직 수행하지 않았습니다.

## 운영 리포트 적용 상태

최초 조회 이후 사용자가 수정·배포를 승인하여 리포트 5개를 Payment Period Date 기준으로 저장했습니다. [배포 및 검증 기록](2026-09-29-commission-report-period.md)에 범위와 링크를 정리했습니다. 개인별 필터·고객 상세·집계 결과는 저장소에 포함하지 않습니다.

| 리포트 | 저장된 기간 조건 |
| --- | --- |
| `Commission By Agent` | Payment Period Date — 이전 회계 분기 |
| `Copy of Commission By Agent` | Payment Period Date — 이전 회계 분기 |
| `Commission_26_Quartely By Agent` | Payment Period Date — 이전 회계 분기 |
| `Biannual Commission By Agent` | Payment Period Date — 2026년 1~6월 고정 |
| `Spec Agent Commission Report` | Payment Period Date — 2026년 7월 고정 |
| `Commission_26_회사,손님,월단위 정리` | 최초 조회에서 Payment Period 필터 사용, 생성일 기간 제한 없음 확인. 이번 변경 대상 아님 |

`Commission_Line__c.Payment_Period__c`는 운영 describe에서 `calculated=true`이고 수식은 `Commission_Statement__r.Payment_Period__c`입니다. 즉 **반환 형식이 Text인 Formula**입니다. 부모 `Commission_Statement__c.Payment_Period__c`는 입력 가능한 일반 Text입니다. 기존 필드는 유지하고, 상대 날짜 필터를 위해 Formula(Date) `Payment_Period_Date__c`를 추가했습니다. 제공된 사례의 Commission Date/Payment Period 차이와 문제 행 포함 여부를 확인했으며, 9/28에 언급한 모든 사례와의 동일성까지 확정하지는 않았습니다.

`Commission_Line__c.Paid_Out__c`도 운영에서 `NOT(ISBLANK(Payout__c))` 형태의 Formula Checkbox임을 확인했습니다. 새 지급 여부 필드는 필요하지 않습니다.

## 완료된 개발과 남은 사용자 확인

| 개발 결과 | 남은 확인 |
| --- | --- |
| [커미션 리포트 지급월 기준 통일](2026-09-29-commission-report-period.md): 운영 배포·리포트 5개 저장, Date/Text 조회 결과 일치 및 문제 행 포함 확인 | 사용자 화면에서 필터·상세 표시 확인. 다른 리포트의 불일치가 있으면 별도 사례 확인 |
| [Commercial·Group Health Lead 회사 정보 및 Flow 전환](2026-09-12-lead-company-flow.md): 운영 배포·활성화 완료 | 일반 사용자 화면에서 회사/개인 주소 분리, 파일·가족 관계 전환 최종 확인 |
| [Agent Payout PDF](2026-09-29-agent-payout-pdf.md): 운영 생성·Files 저장·최신 버전 미리보기 확인 | Kay가 지급 문의에 필요한 상세가 충분한지 확인 |
| [Agent Payout 이메일 템플릿](2026-09-29-agent-payout-email.md): 운영 생성, 실제 값 치환·화면 확인 | 해당 Agent 수신자·최신 PDF를 수동 지정한 뒤 실제 발송/수신 확인 |
| [Insurance Company 및 Renewal 회사 연결](2026-09-12-insurance-company-design.md): 문서상 운영 배포 및 개발 검증 완료 | 일반 사용자 UI, 다음 정기 자동 생성, 기존 누락 Renewal 사례 재확인 |
| Group Health 갱신 이메일: 기존 Quote 기반 구현 및 렌더링 검증 이력 있음 | Kay가 회사명·Carrier·새 Quote 조건 확인, Quote → Closed Won → 새 Insurance 전체 과정 확인 |
| Group Health Policy Number 입력 | 후속 설계 문서에 사용자 검증 완료가 기록돼 있어 미구현 목록에서 제외 |

이번 작업에서는 위 전체 업무 흐름을 다시 실행하지 않았습니다. 특히 관리자/렌더링 검증과 일반 사용자 UI·실제 이메일 수신 검증을 구분합니다.

## 저장소 반영

- 10/2 원격 조회에서 Lead 전환 커밋 `75a2c72`와 PDF·이메일 템플릿 커밋 `460b93d`가 `origin/master`에 반영돼 있음을 확인했습니다.
- 이번 커밋 범위는 지급월 리포트의 필드·ReportType·권한·배포 manifest 및 후속 문서입니다. Insurance 이메일 Contact 보완은 항목 확인 단계이며 기능 구현으로 포함하지 않습니다.
- 사용자가 추가로 저장한 운영 `Lightning_Agent_Payout_Record_Page`의 Related/Activity 탭과 Agent Payout Layout을 임시 프로젝트에서 조회·비교한 뒤 소스에 반영했습니다. 운영에 재배포하지 않았습니다.
- 고객 PDF, 커미션 원본, 인증 파일 및 조회 결과의 개인별 필터 값은 커밋에 포함하지 않습니다.
