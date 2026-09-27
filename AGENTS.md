# K2 Insurance 프로젝트 지침

이 저장소에서 작업하는 코딩 에이전트의 공통 지침입니다. 사용자가 현재 대화에서 정한 작업 범위와 요구사항을 우선하며, 하위 디렉토리에 별도 지침이 있으면 함께 확인합니다.

## 역할과 소통

- K2 Insurance의 Salesforce 개발·운영을 지원합니다. 기존 업무 흐름을 이해하고, 요청한 문제를 해결하는 데 필요한 범위로 변경합니다.
- 사용자에게는 한국어 존댓말로 설명합니다. 코드 식별자, Salesforce API 이름과 기존 UI 언어는 유지합니다.
- 결론을 먼저 말하고, 변경 이유와 업무에 미치는 영향을 간결하게 설명합니다. 확인한 사실과 추정을 구분합니다.
- 조사, 로컬 수정, 필요한 검증은 요청 범위 안에서 진행합니다. 이미 승인된 일을 다시 확인하지 않습니다. 결과를 크게 바꾸는 업무 규칙이나 대상 환경이 불명확할 때만 필요한 질문을 합니다.
- 완료 시 변경 내용, 실제 검증 결과, 배포 여부, 남은 작업을 구분해 보고합니다. 실행하지 않은 테스트나 배포를 완료했다고 표현하지 않습니다.

## 프로젝트 맥락과 탐색

- `README.md` 기준으로 K2 Insurance가 운영하고 5S Infusion이 개발·유지보수하는 Salesforce 메타데이터 및 공개 정적 자산 저장소입니다.
- 기본 소스는 `force-app/main/default/`입니다. API 버전은 `sfdx-project.json`과 대상 Org를 확인합니다. 수정하는 Flow/LWC는 아래 Compliance의 최신 지원 API 요구사항을 적용하되, 작업과 무관한 구성요소의 버전을 일괄 변경하지 않습니다.
- 시작할 때 `git status --short`를 확인하고 기존 미커밋 변경과 새 파일을 보존합니다. 기존 변경을 되돌리거나 요청과 무관한 정리·포맷 변경을 섞지 않습니다.
- 파일 탐색은 `rg`와 `rg --files`를 우선합니다. 관련 기능의 코드, 메타데이터, 테스트부터 읽고 필요할 때 범위를 넓힙니다.
- 원격 저장소 정보는 `git remote -v`로 확인합니다. README의 예시 URL, 프로젝트 이름, 로컬 경로만으로 현재 원격이나 호스팅 설정을 단정하지 않습니다.

| 위치 | 확인할 내용 |
| --- | --- |
| `force-app/main/default/classes/` | Apex 서비스, 컨트롤러, 테스트, 테스트 데이터 팩토리 |
| `force-app/main/default/lwc/` | Lightning Web Components 및 `__tests__/` |
| `force-app/main/default/flows/`, `flowDefinitions/` | 업무 자동화, 서브플로, 활성화 관련 메타데이터 |
| `force-app/main/default/objects/` | 필드, Record Type, Validation Rule, List View |
| `force-app/main/default/permissionsets/`, `profiles/` | 객체·필드·클래스 접근 권한 |
| `force-app/main/default/flexipages/`, `layouts/`, `quickActions/` | 화면 배치와 작업 진입점 |
| `force-app/main/default/labels/` | Custom Labels |
| `manifest/` | 전체 및 기능별 배포·조회 범위, 삭제 메타데이터 |
| `scripts/` | 운영 유틸리티, 배포 및 데이터 변경 스크립트 |
| `email/` | 외부 이메일에서 참조하는 공개 자산. `email/README.md` 확인 |
| `Compliance/` | Apex·LWC·Flow의 상세 개발·검토 표준. 아래 적용 기준 확인 |
| `Commission Statements/` | 월별 보험사 커미션 명세 원본과 내보내기 파일. 아래 임포트 절차 확인 |

## Compliance 적용 기준

- Apex 작업 전 [apex-compliance.md](Compliance/apex-compliance.md), LWC 작업 전 [lwc-compliance.md](Compliance/lwc-compliance.md), Flow 작업 전 [flow-compliance.md](Compliance/flow-compliance.md)를 읽습니다. LWC의 서버 측 변경에는 Apex 표준도 적용합니다. 아래 요약은 원문을 대체하지 않습니다.
- 원문의 `must`/`shall`은 해당 변경의 필수 기준이며 `should`에서 벗어나면 이유를 변경 설명에 기록합니다. 사용자 지시와 실제 플랫폼 지원 범위를 함께 적용하고, 불일치가 있으면 해당 구절·확인 근거·적용한 대안을 명시합니다. 관련 없는 전체 코드 정리나 운영 Flow 버전 삭제로 작업을 확대하지 않습니다.
- **Apex:** ApexDoc의 `@description`, `@param`, `@return` 및 원문에 지정된 `@author` 형식을 따릅니다. 객체당 단일 Trigger와 Handler, 얇은 Controller, 호출자에 독립적인 Service, 부작용 없는 Calculator로 책임을 분리합니다. 명시적 sharing, 별도의 CRUD/FLS 확인, 컬렉션 기반 SOQL/DML, 재실행 안전성, 오류 전파·지속 가능한 로깅을 적용합니다.
- **Apex 테스트:** `Assert`로 실제 결과를 검증하고, 공용 합성 데이터 팩토리와 필요한 `runAs`/callout mock을 사용합니다. 정상·오류·단건·대량 처리를 포함하고, DML/Trigger 관련 대량 시나리오는 원문 기준 최소 20개 레코드로 검증합니다. `SeeAllData=true`와 커버리지만 올리는 테스트는 사용하지 않습니다.
- **LWC:** camelCase 번들, 명시적인 targets, 읽기 전용 `@api`, 단방향 데이터 흐름, 안정적인 반복 key, `lwc:if` 계열 지시문을 사용합니다. 레코드 CRUD는 LDS를 우선하고 schema import를 사용합니다. 표시 문구는 Custom Labels, 스타일은 기본 컴포넌트·SLDS·styling hooks를 사용하며 키보드·초점·접근성 및 wire/imperative 오류 처리를 검증합니다. 번들별 Jest 테스트는 mock을 사용해 DOM·이벤트·공개 API의 동작을 확인합니다.
- **Flow:** Auto-Layout, 대상 Org가 지원하는 최신 실행 API, `YYYY-MM-DD: summary` 형식의 버전 Description을 적용합니다. 기본 구조는 객체별 before-save/after-save 진입점이며 before-save의 플랫폼 제약에 맞춰 분기합니다. 루프 내부 Get/DML을 피하고 컬렉션을 일괄 처리합니다. 지원되는 요소에 Fault 경로, 빈 조회 결과 검사, 지속 가능한 오류 로그와 사용자 안내를 갖춥니다. 변경에 맞는 대량 처리 검증과 Lightning Flow Scanner 결과를 확인합니다.
- **주석과 버전 설명:** Apex/LWC 소스 헤더에는 날짜·티켓·변경 이력을 넣지 않습니다. Flow의 버전 Description에 날짜를 넣는 요구사항과 구분합니다.
- **K2 환경에 맞는 적용:** Apex 표준의 RLM·OmniStudio·다중 통화 및 `Fortra_Exception__e`/`Pricing_Exception__e` 예시는 해당 기능과 구성요소가 실제로 존재할 때만 적용합니다. 현재 K2 소스의 로깅은 `ExceptionLogger.log(...)` → `Exception__e` → `Exception_Event_Logger` → `Error_Log__c`이며 이를 먼저 확인합니다. 원문 예시를 맞추기 위해 다른 환경의 객체·로거·기반 예외 클래스를 임의로 도입하지 않습니다.
- API 지원 여부나 scanner/Jest 실행 환경이 확인되지 않으면 확인하지 못한 기준을 보고합니다. 로컬 정적 검사만으로 Compliance 전체를 통과했다고 표현하지 않습니다.

## Salesforce 구현 원칙

- 새 구조를 도입하기 전에 같은 기능의 기존 패턴을 따릅니다. Flow, Apex, LWC 중 구현 위치는 기존 책임 분리와 요구사항을 기준으로 선택합니다.
- 필드, Record Type, Picklist 값, Custom Label, Apex 메서드 이름을 추정하지 말고 저장소에서 확인합니다. Org 고유 ID와 자격 증명을 코드에 하드코딩하지 않습니다.
- 필드나 기능을 추가·변경할 때 관련 권한, Layout/FlexiPage, Quick Action, Flow, Apex/LWC 참조와 배포 manifest의 의존성을 확인합니다. 필요한 항목만 함께 수정합니다.
- Apex는 여러 레코드를 한 번에 처리할 수 있도록 작성하고, 레코드별 반복문 안의 SOQL/DML을 피합니다. 기존 서비스와 테스트 데이터 팩토리를 재사용합니다.
- 데이터 접근 변경 시 sharing과 객체·필드 권한 처리를 확인합니다. 기존 `WITH USER_MODE` 등의 접근 제어를 테스트 통과 목적으로 제거하지 않습니다. 의도적인 시스템 권한 처리가 있다면 그 목적과 호출 경계를 먼저 확인합니다.
- LWC는 기존 Lightning 컴포넌트와 스타일을 재사용합니다. 추가·수정하는 표시 문구는 Compliance에 따라 Custom Labels를 사용하며, 저장 중 상태·중복 제출·오류 표시를 처리합니다.
- Flow 변경 시 시작 조건, 실행 순서, 재진입, 서브플로, 오류 경로와 상태 변경을 확인합니다. 실제 활성 버전은 필요 시 대상 Org에서 확인하며 로컬 XML만으로 단정하지 않습니다.
- 보험 갱신 작업은 `InsuranceRenewalService`, 관련 테스트, 갱신 Flow를 함께 확인합니다. 현재 코드의 즉시 시작 갱신과 미래 시작 Draft 갱신, `ContactInsuranceAssociation__c` 이관 시점의 차이를 보존하고, 업무 규칙 변경 요청이 있을 때 해당 동작과 테스트를 함께 갱신합니다.
- 커미션·지급 작업은 `Commission_Statement__c`, `Commission_Line__c`, `Agent_Payout__c` 및 `AgentPayout*`의 관계를 확인합니다. 금액 계산·반올림·기간·중복 지급 처리 규칙을 임의로 만들지 않습니다.

## 검증과 배포

- 검증은 변경 범위에 맞춰 수행합니다. 문서만 수정했다면 내용과 diff를 확인하며 Salesforce 배포나 업무 로직 테스트를 실행하지 않습니다.
- Apex 동작 변경은 관련 테스트로 정상·오류·경계 조건과 필요한 대량 처리 동작을 검증합니다. 테스트에는 합성 데이터를 사용하고 운영 고객 데이터에 의존하지 않습니다.
- LWC 테스트는 기존 `__tests__/`를 확인합니다. 현재 저장소 루트에는 `package.json`과 Jest 실행 설정이 없으므로 `npm test`가 가능하다고 가정하지 말고, 작업 시 실행 환경을 먼저 확인합니다. 실행할 수 없다면 이유와 수동 확인 항목을 보고합니다.
- 메타데이터 변경은 XML 구조와 참조 관계를 확인하고, 대상 Org가 확인되면 변경 범위를 좁힌 배포 검증과 필요한 Apex 테스트를 수행합니다. 로컬 검사만으로 Org 호환성이 검증됐다고 주장하지 않습니다.
- Salesforce CLI 명령에는 확인한 `--target-org`를 명시합니다. alias의 이름만으로 Production/Sandbox를 판단하거나 기본 Org에 의존하지 않습니다.
- `manifest/package.xml`에는 다수 메타데이터 유형의 wildcard가 있습니다. 작은 변경에 전체 조회·배포를 기본으로 사용하지 말고, 관련 구성요소와 의존성을 포함하는 기능별 범위를 사용합니다. 기존 기능별 manifest도 현재 파일과 일치하는지 확인합니다.
- 조회(retrieve)는 로컬 파일을 덮어쓸 수 있으므로 기존 diff를 확인하고 범위를 제한합니다. 대상 파일에 미커밋 변경이 있으면 별도 임시 프로젝트에서 조회하여 비교하는 등 기존 작업을 보존합니다.
- 실제 배포, Flow 활성화, 권한 할당, 데이터 변경·삭제, Git push와 공개 자산 게시에는 대화에서 승인된 대상과 범위가 있어야 합니다. 이미 승인됐다면 재확인 없이 진행합니다. 승인이 필요한 경우 먼저 변경안과 검증 결과를 준비하고, 적용 직전에 대상·영향을 제시합니다.
- 스크립트는 실행 전에 실제 명령을 읽습니다. 특히 `scripts/deploy_agent_management.sh`는 최종 단계의 dry-run 이전에 실제 메타데이터 배포와 권한 할당을 수행하므로 단순 검증용으로 실행하지 않습니다. `scripts/apex/`와 `manifest/destructiveChanges.xml`도 적용 내용을 먼저 확인합니다.
- 명령 옵션이 불확실하면 설치된 `sf`의 `--help`를 확인합니다. Salesforce 제품 동작과 제약에 추가 근거가 필요하면 공식 Salesforce 문서를 우선합니다.

## Commission Statements와 임포트 스킬

- `Commission Statements/`는 `Feb`, `Mar`, `Apr`, `May`, `Jun`, `July` 등 월별 폴더에 보험사 원본과 내보내기 파일을 보관합니다. CSV·TSV·XLSX가 섞여 있으므로 파일명 중간의 `.xlsx`/`.xls` 문자열 대신 최종 확장자와 실제 내용을 확인합니다. 원본을 수정·삭제하거나 변환 결과로 덮어쓰지 않습니다.
- 기존 Claude 스킬은 `~/.claude/skills/commission-import/SKILL.md`에 있습니다. 이 Mac에서 확인한 전체 경로는 `/Users/liamjeong/.claude/skills/commission-import/SKILL.md`입니다. 커미션 임포트 요청을 받으면 해당 문서와 같은 폴더의 `providers/*.yaml`, `scripts/`를 먼저 읽습니다. 저장소 밖의 로컬 파일이므로 다른 컴퓨터/원격 환경에서도 존재한다고 가정하지 않습니다.
- 매핑은 `bcbs`, `ambetter`, `humana`, `oscar`, `uhc-group`, `uhc-individual`, `uhone`, `wellpoint`입니다. BCBS는 Individual/Group을 분리하고 UHC는 Group/Individual 형식을 구분합니다. 파일명 패턴과 `header_signature`를 모두 확인하며, 알 수 없는 보험사·열 구조를 임의로 매핑하지 않습니다.
- 스크립트의 역할은 `normalize.py`(열·금액·날짜 정규화), `resolve_map.py`(보험 레코드 후보 정리), `stitch.py`(Statement/Insurance ID 연결), `attach_rest.py`(원본 Salesforce Files 첨부)입니다. 첨부에는 기존 스킬이 지정한 `attach_rest.py`를 사용하고 구형 `attach.py`의 인증 방식을 복제하지 않습니다.
- 현재 스킬의 직접 지원 형식은 CSV입니다. TSV/XLSX는 구분자·시트·헤더를 확인해 임시 CSV로 변환한 뒤 원본 대비 검증합니다. 이미 같은 Excel의 CSV 내보내기가 있다면 함께 중복 임포트하지 않습니다. 원본의 증권번호는 문자열로 보존합니다.

### 임포트 흐름

1. 사용자가 요청한 파일/월과 대상 Org를 확인합니다. 실제 데이터 쓰기는 임포트 요청 범위에서만 수행합니다. 작업별 임시 폴더를 사용해 다른 임포트의 변환 결과와 섞이지 않게 합니다.
2. 보험사와 Individual/Group 유형, `Payment_Period__c`의 `YYYY-MM`을 정합니다. 월은 폴더와 원본 명세의 의미를 대조하고 `July`도 7월로 처리합니다. 지급월·커미션 발생일·보장기간을 혼동하지 않으며, 과거 자료의 연도를 실행 시점의 현재 연도로 자동 확정하지 않습니다.
3. 파일 해시와 원본 행을 비교해 같은 월의 사본, 다른 월에 복제된 파일, Excel/CSV 중복을 확인합니다. 내용이 같다는 이유만으로 정상 지급을 임의로 제거하지 말고 해당 지급월의 자료가 맞는지 확인합니다. Salesforce에서도 보험사 × 지급월 × 유형의 기존 Statement를 조회합니다. 추가 명세나 여러 에이전트 파일을 합칠 때는 원본 출처를 유지하고 기존 행과의 중복을 검증합니다. 스킬의 중복 재임포트 확인 규칙은 이미 해당 중복 처리를 승인한 사용자 지시가 있으면 재질문하지 않습니다.
4. `normalize.py`와 보험사 YAML을 이용해 정규화하고 원본 대비 행 수·금액·날짜를 대조합니다. `Commission_Amount__c`가 실제 API 이름이며, `Commnission Amount`는 레이블의 오타입니다. 음수 환수액과 0을 보존하고 합계/footer를 상세 행으로 임포트하지 않습니다.
5. `Insurance__c` 후보는 상태·계약연도와 관계없이 조회하고, 원본 증권번호와 `Insurance__c.Policy_Number__c`가 문자열 그대로 일치하는 레코드만 고려합니다. `Policy_Number_Imported__c`에는 원본 번호를 항상 보존합니다. 원본 근거로 특정 보험이 확정되면 해당 ID를 연결합니다. 그렇지 않더라도 정확히 같은 번호의 **Active 보험이 전체 후보 중 하나뿐이면 동일 보험으로 추정해** `Policy_Number__c`에 연결합니다. 이때 계약자·회사·이름·상품·기간 차이만으로 보류하지 않고, `Active 추정 연결`로 근거를 기록합니다. Active 후보가 없거나 둘 이상이고 다른 근거로도 특정할 수 없으면 룩업을 비워 둡니다.
6. 대상 Org의 쓰기 가능한 필드와 Picklist를 재확인한 뒤 부모 `Commission_Statement__c`를 만들고 상세 `Commission_Line__c`를 연결해 임포트합니다. 로컬 메타데이터의 Statement `Name`은 AutoNumber이므로 직접 쓰지 않으며 formula/rollup 필드도 입력에서 제외합니다. 현재 상태 값은 `In Process`, `Uploaded`, `Done`, `Need Review`입니다.
7. Bulk API 입력의 실제 줄바꿈과 `--line-ending`을 일치시킵니다. 기존 Python CSV 출력은 CRLF를 사용합니다. 성공 후 원본 파일을 관련 Statement에 첨부하고 `Total_Lines__c`/`Total_Amount__c`를 원본과 대조합니다. 상태는 스킬 절차대로 성공 시 `Uploaded`, 실패 시 `Need Review`로 처리하며, 부분 성공·실패 행·첨부 실패를 구분해 보고합니다. 실패 작업을 전체 재실행하기 전에 이미 생성된 부모와 상세 행을 조회합니다.

### 기존 스킬 재사용 시 보완할 사항

- **Humana 날짜:** `CommRunDt`에는 `D-M-YY` 형식이 실제로 섞여 있고, 현재 `normalize.py`의 날짜 파서는 이를 처리하지 못합니다. 형식을 확인해 임시 사본에서 변환하고 날짜 누락을 검사합니다. Salesforce에는 원본을 첨부합니다.
- **증권번호와 Active 추정 연결:** 앞자리 0·대소문자·구두점·공백을 바꾸어 번호를 일치시키지 않습니다. 정확히 같은 번호에 Active 보험이 하나뿐이면 위 업무 규칙에 따라 연결하고, 이전 연도 Inactive나 이름·상품 차이가 있어도 자동 제외하지 않습니다. Active가 여러 개일 때 최신 시작일이나 Id로 임의 선택하지 않습니다. 임포트 스킬의 `resolve_map.py`/`stitch.py`도 이 정확한 문자열 비교와 유일 Active 규칙을 따라야 하므로, 실행 전 실제 스크립트 동작을 확인합니다.
- **UHC Individual의 복수 Active 후보:** 원본 증권번호가 정확히 같고 Active 보험이 둘 이상이면 보험사·계약자·상품·담당 Agent를 대조합니다. 이 값들이 같고 명세서 지급월을 포함하는 시작일·종료일이 모두 있는 후보가 정확히 하나이며 다른 Active 후보의 기간은 비어 있다면, 기간이 명시된 후보에 **추정 연결**하고 선택 근거를 기록합니다. 지급월만으로 보장월을 확정한 것으로 표현하지 않습니다. 후보들의 신원·상품·Agent가 다르거나 날짜가 있는 후보도 여러 개라면 임의로 선택하지 않습니다. 번호가 정확히 일치하는 후보가 없으면 연결하지 않습니다.
- **Wellpoint 합계:** `Product Subcategory`로 합계 행을 제외하는 매핑을 확인합니다. `skipped_unknown_type_rows`가 실제 합계 행 수와 맞는지 검사해 새 상품 유형의 정상 행이 함께 탈락하지 않게 합니다. 괄호 금액은 환수액으로 처리합니다.
- **Claude의 보충 기록:** `~/.claude/projects/-Users-liamjeong-Documents-Code-K2Insurance/memory/`의 `commission-import-prod-schema-discrepancies.md`, `commission-import-broaden-insurance-match.md`, `humana-commrundt-dash-date.md`, `commission-2025-backfill-mislinked.md`에 스키마 수정과 과거 오류 조사 내용이 있습니다. 이 기록의 운영 수치·상태는 현재 사실로 단정하지 말고 대상 Org에서 재확인합니다. 과거 오류 메모 자체를 운영 데이터 수정의 승인으로 해석하지 않습니다.

## 데이터와 공개 이메일 자산

- README는 저장소를 Public으로 설명합니다. 현재 공개 여부와 관계없이 고객 개인정보, 보험 증권·건강 관련 원본 데이터, 커미션 명세 원본, 자격 증명과 토큰을 커밋하거나 공개 결과물에 포함하지 않습니다.
- `.sf/`, `.sfdx/` 등 인증 관련 파일의 내용을 출력하지 않습니다. 오류 조사에 필요한 로그도 비밀값과 개인정보를 제거합니다.
- `docs/`는 현재 `.gitignore` 대상입니다. 공유 지침이나 전달 문서를 이곳에 저장한 뒤 Git에 포함됐다고 가정하지 않으며, 요청 없이 강제 추가하지 않습니다. `Commission Statements/`의 원본 자료는 해당 데이터 작업에 필요한 경우에만 다룹니다.
- `email/` 자산 변경은 `email/README.md`의 PNG 형식·100KB 이하 등 규격을 따릅니다. 이미 발송된 이메일의 참조를 고려해 기존 파일명과 URL을 함부로 삭제·변경하지 않습니다.
- README와 `scripts/verify-pages.sh`에는 현재 Git 원격 소유자와 다른 호스팅 경로가 들어 있습니다. 주소 변경 시 실제 Pages 설정과 Salesforce 이메일 참조를 확인하며, Git 원격 이름만으로 CDN 주소를 바꾸지 않습니다.
- 공개 자산의 응답 확인에는 `scripts/verify-pages.sh`를 활용하되, 먼저 검사 URL이 실제 사용 중인 주소인지 확인합니다.

## 완료 전 확인

- 자신의 변경 diff와 `git diff --check`를 확인합니다. 새 파일은 별도로 검토하고, 기존 사용자 변경이 보존됐는지 확인합니다.
- 실제 수행한 검증과 수행하지 못한 검증을 구분합니다. 배포했다면 대상 Org, 배포 결과 및 필요한 후속 동작을 보고합니다.
- 이 파일에는 반복해서 적용할 프로젝트 규칙만 유지합니다. 일회성 작업 진행 상황, 임시 Org 정보, 고객 정보는 기록하지 않습니다.
