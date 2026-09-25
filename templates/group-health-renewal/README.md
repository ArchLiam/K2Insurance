# Group Health Renewal email template

This source belongs to the existing **Group Health Renewal 안내, testing** Lightning email template. Its related entity is **Account (Company)**. Compose and send from the Company's standard **Activity → Email** action, keeping **Related To = Company**. `template.json` identifies the existing template and subject; `template.html` contains its HTML body. The existing template identity, name, and personal folder are preserved.

## Company workflow

1. Open the Company and use **Group Health Renewal Email → Group Health Renewal Quote** to select and save the intended Quote.
2. The selection requires a Quote whose parent Renewal belongs to this Company and has the Group Health record type. No latest-Quote or automatic selection rule is used.
3. Open the Company's **Email** action and insert **Group Health Renewal 안내, testing**. Keep the Company in **Related To**, select the recipient, review the values and attachments, then send.
4. If the selected Quote or its terms change after inserting the template, reinsert the template to refresh the email body. Selection is saved on the Company, so it is shared by users viewing that Company.

A Quote must be selected before inserting the template. The standard composer does not enforce Quote selection or complete proposal values at send time. Missing Quote values render blank; they are not populated by this change. The recipient and From address continue to use the standard composer controls.

| Display | Account merge field | Source |
| --- | --- | --- |
| Company in subject and body | `Name` | Current Company |
| Policy holder greeting | `GH_Renewal_Policy_Holder__c` | Selected Quote `Policy_Holder_Name__c` |
| Carrier | `GH_Renewal_Provider__c` | Selected Quote `Insurance_Provider__r.Name` |
| Proposed coverage start | `GH_Renewal_Start_Date__c` | Selected Quote `Proposed_Start_Date__c` |
| Proposed coverage end | `GH_Renewal_End_Date__c` | Selected Quote `Proposed_End_Date__c` |
| Proposed premium | `GH_Renewal_Premium__c` | Selected Quote `Proposed_Premium__c` |
| Proposed plan | `GH_Renewal_Plan__c` | Selected Quote `Plan_Name__c` |
| Plan change deadline | `GH_Renewal_Deadline__c` | Selected Quote `Plan_Change_Deadline__c` |

All seven Account formula fields return blank if the selection is empty or the selected Quote no longer belongs to the Company or a Group Health Renewal. The lookup is optional and clears on Quote deletion. Required lookup filters reject an invalid selection when saving the Company.

The existing Quote policy holder formula reads the parent Renewal's Original Insurance Contact even if `Quote.ContactId` is empty. The coverage end is `ADDMONTHS(Proposed_Start_Date__c, Proposed_Term_months__c) - 1`; missing dates and missing/non-positive terms produce a blank end date. The deadline is one calendar month before the proposed start date. The premium label is **Premium**, since the Quote amount is not intrinsically monthly.

## Deployment

Deploy the eight Account fields, Company FlexiPage, and permissions using [company-renewal-email-package.xml](../../manifest/company-renewal-email-package.xml). Retrieve the current production permission set and page into an isolated project, then add only these changes to preserve production configuration. `K2_Insurance_Admin` grants edit access to the selection and read access to the formulas; no new permission assignments are needed for its existing users.

The Account formulas depend on the existing Quote formulas deployed by [quote-renewal-email-package.xml](../../manifest/quote-renewal-email-package.xml). Deploy that prerequisite first in a new environment. The Company change does not remove the Quote fields or modify the existing Opportunity email action.

The template is in a personal folder. After metadata deployment, update its existing EmailTemplate record by DeveloperName through REST, setting only `Subject`, `RelatedEntityType`, and `HtmlValue` from these sources. Keep Name, DeveloperName, FolderId, and sharing unchanged. Back up the previous values, check for concurrent edits, and compare the saved result. Salesforce may trim a final HTML newline.

Verification uses temporary Anonymous Apex with synthetic records and Savepoint rollback. No verification Apex class is deployed and no email is sent. User review in the Company composer is the final UI check.

## Verified production result

Applied to K2 Insurance production on 2026-09-12 with API 67.0. Validation `0AfPW000010lh7R0AQ` and deployment `0AfPW000010lhNZ0AY` succeeded for 10 metadata components (eight Account fields, the Company page, and the permission set). All 10 existing `InsuranceRenewalServiceTest` tests passed. The deployment used the retrieved production page and permission set; comparison confirmed only the new selector section and eight Account grants were added to those production baselines.

The existing private template was updated in place to Account. Readback confirmed its subject, HTML, and related entity, while preserving its ID, name, DeveloperName, and folder.

Anonymous Apex verified 20 synthetic Company selections and their Quote formula values, including month-end, leap-year, blank-date and zero-term cases. All eight Account merge fields rendered in the stored template. Required filters rejected Quotes from another Company or a non-Group Health Renewal. Selecting another Quote refreshed the merged plan, clearing selection cleared the formula values, and an unsent EmailMessage draft retained the Company in RelatedToId. User-mode access to selection and formulas passed. All synthetic records were rolled back and no email was sent.

The browser UI could not be inspected because computer-control permissions were unavailable. The user still needs to refresh the Company page, select a Quote, insert the template, and review the standard composer before sending. Actual sending was not tested.
