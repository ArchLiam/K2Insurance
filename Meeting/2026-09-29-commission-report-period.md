# 커미션 리포트 지급월 기준 수정

## 현재 상태

2026-09-29 사용자 승인에 따라 K2 Insurance 운영 Org에 날짜 필드·ReportType·읽기 권한을 **배포 완료**했고, 리포트 5개를 저장한 뒤 실제 조회 결과를 검증했습니다.

운영 배포 `0AfPW0000128grd0AA`: **Succeeded, checkOnly=false**, 구성요소 4개, 오류 0. `Agent_Management`, `K2_Insurance_Admin`에는 아래 날짜 필드의 읽기 권한만 추가했습니다. 사용자 할당, 레코드 공유, 편집 권한은 변경하지 않았습니다.

## 변경 구성요소

| 유형 | 항목 | 변경 |
| --- | --- | --- |
| Formula(Date) | `Commission_Line__c.Payment_Period_Date__c` | 기존 `YYYY-MM` 지급월에 `-01`을 붙여 날짜로 계산. 빈 지급월은 빈 날짜 반환 |
| ReportType | `Insurance_with_Commission_Line_Item` | 새 날짜 필드를 리포트에서 선택할 수 있도록 추가 |
| PermissionSet | `Agent_Management`, `K2_Insurance_Admin` | 새 날짜 필드에 읽기 권한만 추가 |

배포 manifest: [commission-payment-period-reporting-package.xml](../manifest/commission-payment-period-reporting-package.xml).

이 날짜는 월별 필터의 기준일이며 실제 Commission Date 또는 Paid Date가 아닙니다. 기존 지급월 Text, Commission Date, 금액 계산 및 지급 기록은 유지합니다. Flow·Apex 추가/변경은 없습니다.

## 리포트별 적용 결과

| 리포트 | 지급월 날짜 필터 |
| --- | --- |
| [Spec Agent Commission Report](https://k2insurance.lightning.force.com/lightning/r/Report/00OPW00001ZRt0X2AT/view) | Payment Period Date — 2026-07-01~2026-07-31 |
| [Commission By Agent](https://k2insurance.lightning.force.com/lightning/r/Report/00OPW00001RYWS12AP/view) | Payment Period Date — `LAST_FISCAL_QUARTER` 유지 |
| [Copy of Commission By Agent](https://k2insurance.lightning.force.com/lightning/r/Report/00OPW00001RZ7eT2AT/view) | 위와 동일 |
| [Commission_26_Quartely By Agent](https://k2insurance.lightning.force.com/lightning/r/Report/00OPW00001RZ7rN2AT/view) | 위와 동일 |
| [Biannual Commission By Agent](https://k2insurance.lightning.force.com/lightning/r/Report/00OPW00001YSXrN2AX/view) | Payment Period Date — 2026-01-01~2026-06-30 |

Agent·보험사 필터, 그룹, 집계 및 Commission Due 수식을 보존했습니다. 기존 상세 열의 Commission Date를 Payment Period로 교체하고, 반기 리포트의 정렬 열도 Payment Period로 맞췄습니다. 특정 월 필터와 분기 자동 필터의 용도를 구분하여 과거 비교용 리포트를 임의로 지난달로 바꾸지 않았습니다.

## 완료한 검증

- 운영 Org 이름 및 `IsSandbox=false`, 회계연도 시작월 1월 확인.
- 부모 Statement의 지급월 20종을 확인했고 모두 `YYYY-MM` 형식입니다.
- 원본 리포트 5개의 설정과 집계 결과, 전체 Permission Set, ReportType을 비공개 임시 경로에 백업했습니다. 리포트의 개인별 필터 값과 집계 결과는 이 저장소에 포함하지 않습니다.
- 배포 사전 검증 `0AfPW0000128Wh00AE`: **Succeeded, checkOnly=true**, 구성요소 오류 0, 기존 `AgentPayoutServiceTest` **34/34 통과**. 실제 Quick Deploy는 이 검증을 재사용했으며 테스트를 다시 실행하지 않았습니다.
- 배포 후 전체 Permission Set을 다시 조회해 새 필드 읽기 권한 외의 기존 필드·객체 권한 등이 동일함을 확인했습니다. 제한 retrieve에서 빠질 수 있는 권한은 전체 Metadata API 조회 백업으로 보존했습니다.
- 배포된 필드가 계산형 Date인지 확인했고 Commission Line **8,539개 / 지급월 20종**의 날짜가 해당 지급월의 1일로 계산됨을 전수 확인했습니다.
- 리포트 5개 모두 새 Date 필터와 같은 기간의 기존 Text 필터로 미리 실행해 행 수·집계·그룹 결과가 일치함을 확인했습니다. 결과는 모두 `allData=true`였습니다.
- 저장 후 5개 리포트의 설정과 실행 결과를 다시 조회해 검증한 변경안과 동일함을 확인했습니다. Agent·보험사 필터, 계산식, 그룹 등 변경 대상 외의 설정도 보존됐습니다.
- 7월 특정 Agent 리포트의 결과는 기존 지급월 Text 필터 결과와 동일하며, 문제였던 **Commission Date 8월 1일 / Payment Period 7월**인 행의 포함 여부도 상세 실행으로 확인했습니다. 원본 리포트에 검증용 열을 저장하지 않았습니다.

검증은 Salesforce Metadata/Analytics API 및 읽기 전용 조회로 완료했습니다. 변경 후 브라우저 화면 렌더링은 이번 실행에서 확인하지 못했습니다. 위 링크에서 Filters의 `Payment Period Date`와 상세의 `Payment Period`를 확인할 수 있습니다. 실제 지급 데이터 변경이나 이메일 발송은 수행하지 않았습니다.

이 작업은 9/12 C1의 지급월 기준 통일 및 제공된 리포트 불일치 사례를 해결합니다. 9/28 A1의 필드 안내와도 관련되지만, 당시 언급한 모든 리포트가 같은 원인이었는지까지 확정한 것은 아닙니다.

## 구현 참고

- [Salesforce DATEVALUE](https://help.salesforce.com/s/articleView?id=sf.customize_functions_datevalue.htm&language=en_US&type=5)
- [리포트 설정 변경 API](https://developer.salesforce.com/docs/analytics/salesforce-analytics-rest-api/guide/sforce-analytics-rest-api-save-report.html)
- [원본을 저장하지 않는 리포트 필터 실행](https://developer.salesforce.com/docs/analytics/salesforce-analytics-rest-api/guide/sforce-analytics-rest-api-filter-reportdata.html)
