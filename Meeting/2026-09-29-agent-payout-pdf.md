# Agent Payout PDF 적용 기록

## 적용 범위

- 사용자가 저장한 `Lightning_Agent_Payout_Record_Page`의 header/main 구성은 유지하고 오른쪽 sidebar에 `agentPayoutPdf`를 추가합니다.
- `K2_Insurance` 앱의 Desktop 기본 Agent Payout 페이지로 지정합니다.
- `Generate PDF`로 해당 지급건에 연결된 Commission Line만 출력하고 Salesforce Files에 저장합니다.
- 미리보기와 다운로드는 저장된 PDF 버전을 사용합니다. 페이지 조회만으로 문서를 생성하지 않습니다.
- 원본 내용이 같으면 같은 버전을 재사용하고, 변경된 경우 같은 File에 새 버전을 추가합니다. 이전 버전은 유지합니다.
- 취소된 지급건은 기존 문서와 VOIDED 안내를 표시하고 재생성을 제한합니다.
- Agent Payout Layout에 Files 관련 목록을 추가합니다.

## 금액의 의미

기존 Agent Payout은 지급 합계를 저장하지만 지급 당시 상세 행별 요율을 별도로 고정하지 않습니다. PDF는 **생성 시점의 연결된 상세와 요율** 및 **기존 지급건에 저장된 합계/실지급액**을 구분하여 출력합니다. 두 값이 다르면 문서와 화면에 안내합니다. PDF 생성으로 지급 금액, 요율, 상태, Commission Line 연결을 변경하지 않습니다.

저장된 PDF 버전의 내용은 그대로 유지됩니다. 지급 이후 요율이 바뀌어 재생성하는 경우, 새 버전이 지급 당시 상세를 복원하는 것은 아닙니다.

## 구성요소

배포 범위: [agent-payout-pdf-package.xml](../manifest/agent-payout-pdf-package.xml).

| 유형 | 구성요소 |
| --- | --- |
| Apex | `AgentPayoutPdfController`, `AgentPayoutPdfPageController`, `AgentPayoutPdfService` |
| Apex 검증 | 위 클래스의 Test 3개 및 `AgentPayoutPdfTestData` |
| Visualforce | `K2AgentPayoutPdf`, `K2AgentPayoutPdfPreview` |
| LWC | `agentPayoutPdf` 및 Jest 테스트 |
| Agent Payout 필드 | `Statement_File_Id__c`, `Statement_Source_Hash__c`, `Statement_Generated_At__c` |
| 화면 | `Lightning_Agent_Payout_Record_Page`, `Agent Payout Layout`, `K2_Insurance` 앱 |
| 권한 | `Agent_Management`, `K2_Insurance_Admin`의 PDF 클래스/페이지 및 관련 필드 접근 |
| 표시 문구 | `PayoutPdf_*` Custom Labels |

운영에서 현재 메타데이터를 별도 임시 프로젝트에 조회하고, 앱/권한/레이아웃의 기존 운영 설정에 이 기능만 추가하여 배포합니다. 저장소의 오래된 설정으로 운영 설정을 덮어쓰지 않습니다.

## 동작 한계와 확인 방법

- 한 지급건당 최대 5,000행을 지원합니다. 초과하면 일부 행만 출력하지 않고 생성을 거절합니다.
- 1.5MB 이하의 저장 PDF를 오른쪽에 표시합니다. 더 큰 문서는 `Open Preview`와 다운로드를 사용합니다.
- 원본 변경 감지는 페이지 재조회/패널 새로고침 시 확인할 수 있습니다.
- 표준 Files 접근 권한과 레코드/필드 권한을 적용하며 공개 File URL을 만들지 않습니다.
- Flow 및 기존 지급 계산/취소 로직은 변경하지 않습니다.

## 검증과 배포

- 운영 Org: K2 Insurance, `IsSandbox=false`, API 67.0 지원 확인.
- 기본 기능 69개 구성요소 검증: `0AfPW0000128L410AE`, Apex 12개 통과.
- 기본 배포: `0AfPW0000128LlZ0AU`, 성공. 앱의 기존 Profile별 페이지 지정 242개 보존을 재조회하여 확인했습니다.
- 원본 비교값 보완: `0AfPW0000128NCH0A2`, 성공, Apex 12개 통과. 호출/Visualforce 트랜잭션 간 값의 순서가 달라지지 않도록 고정된 필드 순서로 해시를 계산합니다.
- 실제 화면 버튼으로 PDF 1개를 Files에 저장했습니다. 저장된 문서의 3페이지 모두 렌더링하여 확인했고, 상세 50행과 요율 미지정 2행, 합계와 반복 표 머리글을 대조했습니다.
- 생성 전후 지급 금액·기간·상태·50개 상세 행 연결과 금액이 동일함을 조회 해시로 확인했습니다.
- LWC Jest 8개 통과. 저장 파일 버전 선택, 중복 클릭, 새 버전 전환, 취소 상태, 오류 후 버튼 복구를 검증합니다. 루트 Jest 설정이 없으므로 별도 임시 프로젝트에서 `@salesforce/sfdx-lwc-jest` 7.9.0으로 실행했습니다.

Lightning Web Security는 iframe 주소에 HTTP(S)를 요구하므로, 저장된 PDF를 인증된 Visualforce 미리보기 페이지 안에서 표시합니다. LWC에는 HTTPS 페이지 주소만 전달하며 조직 전체 PDF 다운로드 보안 설정은 변경하지 않습니다. 근거: [Salesforce LWS iframe 제한](https://developer.salesforce.com/docs/platform/lightning-components-security/guide/lws-iframes.html).

읽기 전용 `cacheable` Apex/Visualforce 조회에서는 DML 기반 로그를 남길 수 없으므로 오류를 사용자에게 전달합니다. 저장 작업의 예외는 기존 `ExceptionLogger`를 사용하고 트랜잭션을 되돌립니다. 관련 없는 Flow/전체 저장소 Compliance 검증을 수행한 것으로 보지 않습니다.

- 최종 HTTPS 미리보기 배포: `0AfPW0000128OwL0AU`, 성공. Apex **13/13**, LWC Jest **8/8** 통과. 두 Permission Set의 PDF 페이지 2개 접근 및 앱/레이아웃 설정을 배포 후 재조회했습니다.

- 운영 레코드 페이지에서 **오른쪽 PDF 3페이지 미리보기**, **Version 1/생성 일시**, **Files (1)** 및 재생성·확대·다운로드 버튼 표시를 실제 브라우저로 확인했습니다. Lightning의 이전 컴포넌트 캐시를 갱신한 후 확인한 결과입니다.
- 기존 앱 Profile별 지정은 내용까지 동일하며, 두 Permission Set의 기존 필드 권한이 모두 보존됐음을 비교했습니다.
- 최종 배포 manifest는 70개 구성요소입니다. 기능 적용 당시 Git commit/push는 실행하지 않았으며, 후속 커밋·푸시 작업은 [9/29 현황](2026-09-29-open-items.md)에 정리했습니다.

- 이후 사용자가 저장한 Related/Activity 탭 및 Layout을 운영에서 다시 조회하여 저장소에 반영했습니다. 최신 화면 구성을 보존하기 위한 조회이며 추가 배포는 수행하지 않았습니다.
