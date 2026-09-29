# A2. Lead 회사 정보 및 Flow 전용 전환

기준일: 2026-09-28. K2 Insurance Production에 배포하고 세 Flow를 활성화했습니다. 배포 후 메타데이터와 사용자 필드 접근을 다시 조회해 확인했습니다.

## 동작

- 표시 이름: **Convert to Account & Contact**. 기존 Quick Action API 이름과 진입점은 유지합니다.
- Commercial/Group Health Lead의 회사 정보를 Account에 전달합니다. 회사 주소는 새 Lead Company 주소 필드 → Account Billing Address, 개인 주소는 기존 Lead 주소 → Contact Mailing Address로 분리합니다.
- 유효한 Company 이름이 있을 때 Account를 생성하는 기존 조건을 유지합니다. 다른 Lead 유형에는 Commercial/Group Health 전용 회사 상세를 적용하지 않습니다.
- 상담 메모는 `Lead.Important_Note__c` → `Contact.Important_Note__c`에 서식을 유지해 복사합니다. 이 필드를 별도의 Salesforce Note로 생성하던 Apex 호출은 제거했습니다.
- 기존 Salesforce Files는 원본 문서를 복제하지 않고 새 Contact에 연결합니다. 원래 Lead의 연결과 파일의 ShareType/Visibility를 유지합니다.
- Lead는 보존하고 `Contact__c`와 `Status = Qualified`를 갱신합니다. Salesforce 표준 `IsConverted`를 직접 수정하지 않습니다.
- 이미 Contact가 연결된 Lead는 다시 생성하지 않습니다. 함께 전환되는 가족과 기존 전환된 가족의 Primaryholder 연결을 반영합니다.

## Flow 구조

| Flow | 역할 |
| --- | --- |
| `Lead_to_Contact_Conversion` | 화면·가족 선택·성공 안내. 선택한 Lead ID를 모아 한 번 호출하고 실패하면 Roll Back Records 후 오류 화면을 표시합니다. |
| `Lead_Convert_Single` | 기존 단건 인터페이스를 보존하는 래퍼. 단건 ID를 컬렉션으로 전달합니다. |
| `Lead_Convert_Collection` | Account/Contact 생성, Lead 갱신, 가족 관계와 파일 연결을 컬렉션으로 처리합니다. |

Account와 Contact에 `Conversion_Source_Lead__c` 룩업을 추가해 생성된 레코드를 원래 Lead ID로 정확히 매칭합니다. 이름이나 컬렉션 순서에 의존하지 않으며 업무 화면에는 이 기술 필드를 추가하지 않습니다.

파일 조회는 `ContentDocumentLink.LinkedEntityId IN targetLeadIds` 조건의 Get Records 한 번으로 수행합니다. 루프에서는 메모리 내 필터·분기·컬렉션 Assignment만 실행하며, 모든 조회와 DML 및 변환 서브플로 호출은 루프 밖에 있습니다.

단건 Flow와 컬렉션 Flow는 `succeeded`, `errorMessage`, `errorStep`, `convertedCount`를 반환합니다. 실패 시 호출하는 화면 Flow가 롤백해야 합니다. 새로운 호출자를 추가할 때도 이 계약을 지켜야 합니다.

## 생성·수정 컴포넌트

기능 manifest: [`lead-company-information-package.xml`](../manifest/lead-company-information-package.xml). ApexClass 항목은 없습니다.

| 구분 | 유형 | API 이름 | 수 |
| --- | --- | --- | ---: |
| 생성 | CustomField | `Lead.EIN__c`, `Lead.Company_Type__c`, `Lead.Standard_Industry_Code_SIC__c` | 3 |
| 생성 | CustomField | `Lead.Company_Street__c`, `Lead.Company_City__c`, `Lead.Company_State__c`, `Lead.Company_Postal_Code__c`, `Lead.Company_Country__c` | 5 |
| 생성 | CustomField | `Account.Conversion_Source_Lead__c`, `Contact.Conversion_Source_Lead__c` | 2 |
| 생성 | ValidationRule | `Lead.EIN_Validation_Rule` | 1 |
| 생성 | Flow | `Lead_Convert_Collection` | 1 |
| 수정 | Flow | `Lead_Convert_Single`, `Lead_to_Contact_Conversion` | 2 |
| 수정 | FlexiPage | `Commercial_Group_Health_Lead_Record_Page` | 1 |
| 수정 | Layout | `Lead-Commercial Group Health Layout` | 1 |
| 수정 | RecordType | `Lead.Commercial_Group_Health` | 1 |
| 수정 | PermissionSet | `K2_Insurance_Admin` | 1 |
| 수정 | QuickAction | `Lead.Convert_to_Contact` | 1 |
| **합계** | | **생성 12 / 수정 7** | **19** |

이 기능을 위해 추가했던 `LeadConversionFiles`, `LeadConversionFilesTest`, `LeadCompanyConversionTest`, `LeadCompanyTestData`와 각 메타데이터 파일을 제거했습니다. 전환 Flow에는 Apex Action이 없습니다. 다른 기능의 기존 Apex와 공통 오류 로깅 구성은 변경하지 않습니다.

## Compliance 확인 범위

- 세 Flow 모두 Auto-Layout, 대상 Org 최신 실행 API 67.0, `2026-09-28: summary` 형식의 버전 설명을 사용합니다.
- RecordType ID는 DeveloperName으로 조회하며 하드코딩하지 않습니다. 조회 결과의 빈 값과 파일·가족 컬렉션의 빈 값을 분기합니다.
- 모든 전환 Get/Create/Update에 Fault 경로를 연결했습니다. 기존 `Log_Error` → Publish Immediately `Exception__e` → `Exception_Event_Logger` → `Error_Log__c`를 재사용합니다.
- Subflow 요소에는 플랫폼상 Fault connector가 없으므로 내부 데이터 요소에서 오류를 잡고 명시적인 성공/오류 출력으로 전달합니다. 이는 §3.1에 대한 플랫폼 제약에 따른 대안입니다. 공통 로거 자체의 실패나 플랫폼 governor-limit 예외까지 처리할 수 있다는 의미는 아닙니다.
- 사용자가 전환 완료 직후 확인할 회사·Contact·가족·파일 연결이므로 동기 처리합니다. 부모 화면 Flow와 자식 Flow가 같은 레코드를 따로 갱신하지 않습니다.
- Lightning Flow Scanner: 세 Flow 모두 오류 0 / 경고 0. 별도 그래프 검사에서도 루프 내부 데이터 요소와 서브플로 호출 0건입니다.
- XML 참조 검사와 `git diff --check`를 수행했습니다.
- Org check-only 동작 테스트 결과는 아래 검증 기록에 기재합니다. 로컬 정적 검사만으로 전체 준수를 확정하지 않습니다.

## 검증 기록과 배포 경계

2026-09-28 K2 Insurance Production 대상 **배포 전 check-only 성공**: `0AfPW0000121PnV0AU` (`checkOnly = true`). 컴포넌트 오류 0건, 테스트 **25/25 통과**입니다. 이 검증 작업은 운영 배포·활성화·업무 데이터 쓰기를 수행하지 않았습니다.

임시 `LeadFlowOnlyValidationTest` 7개와 기존 `LeadFormControllerTest` 18개를 실행했습니다.

| 검증 항목 | 결과 |
| --- | --- |
| Commercial/Group Health 200건을 한 컬렉션 Flow 인터뷰로 전환 | 200건의 Account/Contact 매칭, 회사 상세·주소·메모 보존 확인. SOQL/DML 각각 20회 미만 조건 통과. |
| 위 200건 중 파일을 첨부한 20건 | 원래 문서가 해당 Lead의 Contact에 각각 한 번 연결되는지 확인. |
| 같은 200건 재실행 | 신규 전환 0건, Account/Contact 중복 생성 없음. |
| Health/Medicare/Others 각 20건 | 개인 주소 및 회사 생성 조건 보존, 사업용 상세가 다른 유형에 복사되지 않음. |
| 가족 관계 | 주가입자와 신규 가족 20명, 이전에 전환된 가족 1명의 Contact 연결 확인. |
| 선택 상세가 빈 회사 20건 및 단건 래퍼 | 빈 회사 상세·주소 처리와 단건 전환 정상. |
| 빈 입력·잘못된 ID | 실패 상태, 메시지, 실패 단계 반환. |
| 잘못된 EIN 20건 및 권한 | Validation Rule 거부와 필요한 필드 접근 확인. |
| 기존 웹 접수 회귀 | `LeadFormControllerTest` 18개 통과. |

검증 패키지의 세 FlowDefinition 활성화 검사도 통과했습니다. 변경된 서브플로를 기존 활성 버전과 처음 대조할 때 발생한 중간 Info 메시지는 최종 활성화·테스트 실패가 아니며, 테스트/Flow 커버리지 경고는 없습니다.

화면의 실제 렌더링·클릭 동작과 오류 화면의 롤백 경로는 별도 수동 확인 대상입니다. 이전 운영 Flow 버전은 보존했으며, 오래된 버전 삭제는 이번 배포에 포함하지 않았습니다.

검증용 임시 Apex는 저장소와 기능 manifest에 포함하지 않습니다. 임시 테스트를 포함한 check-only 패키지를 그대로 Quick Deploy하지 않습니다. 실제 배포에는 기능 manifest와 대상 Org에서 다시 확인한 세 Flow의 활성화 구성을 사용해야 합니다.

## 운영 배포 및 활성화 결과

사용자의 배포·활성화 승인 후 **2026-09-28 18:31:46 America/Chicago**에 배포가 성공했습니다.

- 배포 ID: `0AfPW0000122e690AA`, `checkOnly = false`, `Succeeded`.
- 기능 컴포넌트 19개와 FlowDefinition 3개를 함께 배포했습니다. Metadata API 집계는 부모 CustomObject 3개를 포함해 25개입니다.
- 실제 배포 중 기존 `LeadFormControllerTest` **18/18 통과**, 컴포넌트 오류 0건, 테스트 오류 0건.
- 기능용 Apex 4개와 임시 검증용 Apex 2개가 운영 Org에 없음을 재확인했습니다.
- 배포 직전 별도 임시 프로젝트에 기존 구성과 활성 버전을 백업했습니다. 기존 Record Type 선택값·기본값을 보존했습니다.

| Flow | 실제 활성 버전 | 상태 |
| --- | ---: | --- |
| `Lead_to_Contact_Conversion` | 16 | Active |
| `Lead_Convert_Single` | 2 | Active |
| `Lead_Convert_Collection` | 1 | Active |

활성화 manifest는 [`lead-company-information-activation-package.xml`](../manifest/lead-company-information-activation-package.xml)입니다. 기록된 버전 번호는 이번 운영 배포의 결과이며, 이후 재배포나 다른 Org 적용 시 대상 버전을 다시 확인해야 합니다.

배포 후 조회로 Lightning 페이지·Layout의 Lead 회사 필드 8개, Description 표시, Permission Set의 필드 권한 12개, Quick Action 표시 이름, EIN Validation Rule 활성 상태를 확인했습니다. 현재 사용자 UI API에서도 회사 필드 8개가 조회·생성·수정 가능한 상태입니다. 기존 Lightning 페이지는 K2 Insurance 앱의 Admin 프로필에 PC·모바일 모두 할당되어 있으며, 이번 작업은 페이지 할당 범위를 변경하지 않았습니다.

## 사용자가 확인할 링크와 순서

- [Commercial Group Health 페이지 레이아웃](https://k2insurance.lightning.force.com/lightning/setup/ObjectManager/Lead/PageLayouts/00hPW000008Q5M1YAK/view)
- [Lead Lightning 페이지 설정](https://k2insurance.lightning.force.com/lightning/setup/ObjectManager/Lead/LightningPages/view): `Commercial Group Health Lead Record Page`를 선택합니다.
- [Commercial / Group Health Lead 새로 만들기](https://k2insurance.lightning.force.com/lightning/o/Lead/new?recordTypeId=012PW00000JaNb3YAF)

K2 Insurance 앱에서 확인용 Lead를 사용해 다음 항목을 확인합니다.

1. 회사 Description, EIN, Company Type, SIC, Company Address가 보이고 수정되는지 확인합니다. 개인 주소와 회사 주소를 서로 다르게 입력합니다.
2. EIN은 `12-3456789` 형태로 저장되고, 잘못된 형식은 거부되는지 확인합니다. 빈 값은 허용합니다.
3. **Convert to Account & Contact**를 실행하고 완료 안내에서 Contact로 이동합니다.
4. Account의 회사 상세·Billing Address, Contact의 Mailing Address·Important Note·Files를 확인합니다.
5. 원래 Lead에 Contact가 연결되고 Status가 Qualified인지 확인합니다. 다시 전환해도 중복 생성되지 않아야 합니다. 가족을 함께 선택했다면 Primaryholder 연결도 확인합니다.

이 수동 확인을 대신해 운영 고객 Lead를 자동으로 전환하거나 별도의 테스트 고객 데이터를 생성하지 않았습니다.
