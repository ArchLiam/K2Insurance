# Agent Payout 이메일 템플릿

## 운영 적용

- 2026-09-29 K2 Insurance 운영 Org에 `Agent Payout 지급 내역 안내` 템플릿을 생성했습니다.
- API 이름: `K2_Agent_Payout_Statement`
- Lightning Email Template (`custom` / `SFX`), `Public Email Templates` 폴더, Related Entity Type은 `Agent_Payout__c`입니다.
- 기존 `K2 Master Layout (Header & Footer) Copy 후 사용`의 헤더·푸터와 연락처를 재사용합니다. 본문은 한국어·영어 병기입니다.
- [템플릿 열기](https://k2insurance.lightning.force.com/lightning/r/EmailTemplate/00XPW00000xK7Zd2AK/view)
- 조회한 운영 소스를 저장소에 보관했습니다. 재배포 범위는 [agent-payout-email-package.xml](../manifest/agent-payout-email-package.xml)입니다.

## 자동 입력 항목

| 표시 항목 | Merge field |
| --- | --- |
| Agent명 | `Agent_Payout__c.Agent__c` |
| 지급 번호 | `Agent_Payout__c.Name` |
| 지급 대상 기간 | `Agent_Payout__c.Period_Label__c` |
| 실지급액 | `Agent_Payout__c.Amount_Paid__c` |
| 지급일 | `Agent_Payout__c.Paid_Date__c` |

제목에는 지급 대상 기간과 지급 번호가 들어갑니다. Agent명은 Payout의 Agent Account 룩업에서 가져오며 수신자 이메일을 자동으로 설정하지 않습니다.

## 사용 방법

1. Paid 상태의 Agent Payout에서 Email을 엽니다.
2. `To`에 해당 Agent의 이메일/Contact를 지정하고 `Related To`가 해당 Agent Payout인지 확인합니다.
3. Insert a template에서 `Agent Payout 지급 내역 안내`를 선택합니다.
4. 오른쪽 Payout Statement 패널에서 PDF가 최신인지 확인하고, 필요하면 Regenerate PDF를 실행합니다.
5. 첨부 아이콘에서 해당 지급건의 `K2_Payout_` PDF를 선택합니다. Salesforce 파일 선택이 어려우면 오른쪽 Download로 저장한 PDF를 첨부할 수 있습니다.
6. 수신자, 지급 정보, 첨부 PDF를 확인한 뒤 발송합니다.

템플릿에는 PDF를 고정 첨부하지 않았습니다. 지급건마다 다른 파일을 사용하는 재사용 템플릿이므로, 해당 레코드의 최신 PDF를 각 이메일에 첨부해야 합니다. 본문 삽입만으로 PDF나 수신자가 자동 설정되지는 않습니다.

## 검증과 범위

- 운영에서 `Messaging.renderStoredEmailTemplate`로 실제 지급건을 렌더링했습니다. 이메일 발송은 수행하지 않았습니다.
- Agent 룩업이 이름으로 표시되고, 제목·본문의 지급 번호와 기간, 통화 형식의 실지급액, 지급일이 해당 레코드 값과 일치하는 것을 확인했습니다. 미치환 merge field가 남지 않았습니다.
- Lightning 템플릿 상세 화면에서 Related Entity Type, 공용 폴더, 한국어·영어 본문, 요약 표 및 K2 헤더·푸터를 확인했습니다.
- 실제 수신함의 이메일 클라이언트별 표시와 전달 여부는 검증하지 않았습니다.
- 템플릿 생성 과정에서 기존 레코드 페이지, PDF 생성 기능, Flow, Apex, 권한과 지급 데이터는 변경하지 않았습니다. 후속 커밋·푸시 작업과 잔여 항목은 [9/29 현황](2026-09-29-open-items.md)에 정리했습니다.
