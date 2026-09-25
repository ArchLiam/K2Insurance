# Insurance Company 연결 및 Renewal 반영

기준일: 2026-09-12. 회의 액션 아이템 2번의 설계 및 적용 결과입니다.

- 1번 Policy Number: 사용자 검증 완료.
- 2-A 보험 Company 입력·연결: 사용자가 Group Health Lightning 화면에 `Insurance__c.Company__c`를 추가하고 검증 완료를 확인했습니다.
- 2-B Renewal 회사 연결: K2 Insurance 운영 Org에 배포·활성화하고 개발 검증을 완료했습니다. 사용자 화면 검증이 남았습니다.
- 2-C 기존 데이터 보완: 미진행. 검토한 대상과 범위를 정한 후 별도로 처리합니다.
- 이후 추가 배포는 검증 결과와 컴포넌트별 변경 목록을 먼저 사용자에게 제시합니다.

## 회사 연결 기준

| 정보 | 필드 | 역할 |
| --- | --- | --- |
| 보험의 대상 회사 | `Insurance__c.Company__c` | 기존 Client Business Account Lookup 사용 |
| 계약자 | `Insurance__c.Policy_Holder__c` | Contact 연결 유지 |
| 보험사 | `Insurance__c.Insurance_Provider__c` | 보험사 Account 연결 유지 |
| Renewal의 회사 | `Opportunity.AccountId` | 원본 보험의 Company와 일치 |

적용 대상은 원본 Insurance의 Record Type이 `Commercial` 또는 `Group_Health`인 Renewal입니다. Contact의 기본 Account로 회사를 추정하지 않습니다.

## 운영 Org에서 확인한 기준

- 명시적 대상은 `liam.jeong@k2ins.com`이며, Organization 이름 K2 Insurance 및 `IsSandbox = false`를 조회해 확인했습니다.
- 운영 Org의 최신 지원 API는 67.0입니다. 수정한 Flow에 67.0을 사용했습니다.
- 자동 생성 Flow의 기존 활성 버전은 10, 생성 범위는 종료일이 오늘 이상이고 90일 미만인 보험입니다. 기존 90일 조건, Daily 일정, 시작 시각 `05:00:00.000Z`, 중복 방지 조건 및 Auto/Home 제외를 유지했습니다. 로컬의 60일 표기는 운영 기준으로 맞췄습니다.
- 기존 자동 생성은 Renewal Account에 보험사 `Insurance_Provider__c`를 넣었습니다. 이번 변경은 대상 기업 보험에서 Company를 사용합니다.
- 기존 `Renewal_Before_Save_Record_Triggered_Flow`와 `Renewal_After_Save_Record_Triggered_Flow`는 활성 버전이 없었습니다. 기존 상태 전환 로직을 다시 활성화하지 않고 회사 연결만 담당하는 Opportunity before-save 진입점을 추가했습니다.
- Org 전체의 `enableFlowDeployAsActiveEnabled`는 false입니다. 이 설정을 바꾸지 않고 이번 두 Flow의 `FlowDefinition`으로 활성 버전을 명시했습니다.
- 운영 `InsuranceRenewalService`는 로컬 버전과 다릅니다. 운영은 미래 시작 갱신도 Active로 생성하며 로컬에는 미래 Draft 처리가 있습니다. 이번 배포에는 서비스·기존 테스트·보험 상태 전환 변경을 포함하지 않았습니다.

## 실제 배포 목록

| 유형 | 컴포넌트 | 변경 내용 |
| --- | --- | --- |
| Flow | `Daily_Generate_Renewal_Opportunities` | 대상 보험의 Renewal Account를 Company로, 자동 생성 이름을 회사명으로 설정. Company 누락 시 생성 보류 및 기존 `Log_Error` 경로로 기록 |
| Flow | `Opportunity_Before_Save_Record_Triggered_Flow` | 빈 Account에 원본 Company 설정. 신규·주요 변경 시 회사 누락/불일치 차단. 관련 없는 기존 기록 편집과 Closed 이력 보존 |
| ListView | `Insurance__c.Company_Required_For_Renewal` | Company가 없는 Active Commercial·Group Health 보험 확인 목록 추가 |
| FlowDefinition | `Daily_Generate_Renewal_Opportunities` | 버전 11 활성화 |
| FlowDefinition | `Opportunity_Before_Save_Record_Triggered_Flow` | 버전 1 활성화 |

기능 소스 manifest는 [renewal-company-package.xml](../manifest/renewal-company-package.xml)입니다. 운영 버전 번호를 담은 FlowDefinition은 임시 배포 프로젝트에서만 사용했습니다.

`RenewalCompanyTestData`와 `RenewalCompanyFlowTest`는 사용자 지시에 따라 로컬 및 배포 목록에서 제거했습니다. 검증용 Apex 메타데이터는 운영 Org에 반영하지 않았습니다. 업무 Flow 2개, ListView 1개 및 활성화 정보 2개가 실제 배포 범위입니다.

## 적용된 저장 규칙

| 상황 | 동작 |
| --- | --- |
| 자동 생성, 원본 Company 있음 | Account에 Company 설정, 이름은 `Renewal - 회사명 (기존 보험 종료일)` |
| 자동 생성, Company 없음 | 해당 보험의 생성 보류, 누락 기록 및 확인 목록 제공 |
| 원본 Company가 있고 Renewal Account가 비어 있음 | before-save에서 Company로 채움 |
| 신규 생성 시 Company 없음 또는 Account 불일치 | 안내 메시지와 함께 저장 차단 |
| 기존 Open Renewal의 불일치 | 메모 등 일반 편집 허용. Account·원본 보험·Stage·Record Type 변경 시 연결 정정 요구 |
| 원본 보험 Company 변경 | 기존 Renewal에 즉시 전파하지 않음. 명시적인 연결 정정 필요 |
| 이미 Closed이고 Stage가 같은 기록 | 회사 재설정·검증을 생략하여 이력 편집 보존 |
| 다른 보험 유형 | 기존 Account 동작 유지 |

수동 생성 화면은 현재 Account 입력을 필수로 요구합니다. 사용자는 원본 보험의 Company와 같은 Account를 선택해야 합니다. 이번 변경의 빈 Account 기본값은 저장 요청에 Account가 없는 경우에 동작하며, 화면에서 원본 보험 선택 즉시 채워지는 UI 기능을 추가한 것은 아닙니다. 수동 입력한 Renewal 이름도 자동 변경하지 않습니다.

before-save의 조회 실패와 검증 오류는 Custom Error로 안내합니다. 이 실행 문맥에서는 이벤트 발행·Apex Action·Subflow를 통한 지속 로그를 추가하지 않았습니다. Compliance §3.5의 before-save 예시는 실제 플랫폼 지원 범위에 맞춰 적용했습니다. [Salesforce Custom Error 문서](https://help.salesforce.com/s/articleView?id=sf.flow_ref_elements_custom_error.htm&language=en_US&type=5)

## 실제 검증 결과

| 검증 | 결과 |
| --- | --- |
| XML 구조·Flow 연결 참조 및 변경 파일 whitespace 검사 | 통과 |
| 제한 배포 사전 검증 | 성공, 기존 `InsuranceRenewalServiceTest` 10개 통과 |
| 실제 운영 배포 | 성공, 컴포넌트 5개 및 기존 테스트 10개 통과. 배포 ID `0AfPW000010leRJ0AY` |
| 활성 버전 재조회 | Daily 11, Opportunity before-save 1 확인. 기존 Renewal before/after Flow는 활성 버전 없음 |
| 일회성 Anonymous Apex | 200건 생성·반복 저장에서 원본 Company 일치 확인 |
| Anonymous Apex 오류·경계 시나리오 | 보험사 Account 거부 20건, 기존 불일치 일반 편집·Stage 차단·명시적 정정 20건, Company 누락 거부 20건, Closed 이력 20건, 다른 보험 유형 20건 통과 |
| 합성 데이터 정리 | Savepoint 롤백 및 합성 Account 잔존 0건 검증 통과 |
| Lightning Flow Scanner | 변경 Flow 2개 검사, 오류 0건. 전체 필드 저장 관련 경고 3건 및 실행 순서 관련 안내 2건 검토 |

Scanner의 전체 필드 저장 경고는 Daily의 기존 조회 2개와 새 원본 보험 조회 1개입니다. 현재 조회는 단일 레코드이며 루프 내 조회/DML은 없습니다. 실행 순서는 새 before-save 진입점이 하나인 현재 구성에서 별도로 지정하지 않았습니다. Salesforce Code Analyzer의 Flow 엔진은 로컬 Python 3.9 환경 때문에 실행하지 못했고, 독립 실행형 Lightning Flow Scanner Core로 검사했습니다. Compliance 전체 무결함 판정을 의미하지 않습니다.

검증 코드는 임시 경로의 Anonymous Apex로 실행했습니다. 합성 Account·Contact·Insurance·Opportunity만 만들고 같은 트랜잭션에서 롤백했습니다. 기존 고객 레코드 일괄 보정은 수행하지 않았습니다.

## 사용자 확인 및 남은 범위

1. Company B의 Commercial 또는 Group Health 보험에서 수동 Renewal을 생성하고 Account B를 선택해 저장합니다. 같은 Contact가 Company A에 연결되어 있어도 B로 유지되는지 확인합니다.
2. 해당 Renewal에서 Account를 다른 회사 또는 보험사로 바꾸면 안내 후 저장이 차단되는지 확인합니다.
3. `Company Required for Renewal` 목록이 표시되는지 확인합니다. Company가 없는 보험의 신규 Renewal은 먼저 원본 Company를 지정하도록 안내해야 합니다.
4. 다음 정기 자동 생성 결과에서 Renewal Account와 이름이 원본 Company를 사용하는지 확인합니다. 실제 예약 실행은 이번 Anonymous 검증에서 강제로 실행하지 않았습니다.

- 일반 사용자 프로필의 FLS·공유 및 UI 경로는 별도 사용자 검증이 필요합니다. 관리자 Anonymous 실행 결과를 일반 사용자 권한 검증으로 간주하지 않습니다.
- 기존 Closed Won 후 새 보험 생성 Flow가 비활성인 사실을 확인했습니다. 이번 변경은 해당 전체 업무 흐름을 복구하거나 Quote부터 새 보험 생성까지 검증한 작업이 아닙니다.
- 직접 갱신의 Company/Policy Holder 승계는 사전 검증 중 합성 20건에서 확인했으며 기존 운영 갱신 테스트 10개도 통과했습니다. 미래 Draft 동작은 이번에 운영으로 배포하지 않았습니다.
- 보험 생성 자체의 Company 필수 Validation Rule, 도움말·이력 추적 및 추가 권한 변경은 최초 설계의 검토안으로 남아 있으며 이번에 적용하지 않았습니다.
- 2-C 기존 Open Renewal 보정과 액션 아이템 3번 이메일 변경은 이번 범위에 포함하지 않았습니다.
