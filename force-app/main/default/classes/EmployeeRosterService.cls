/**
 * @description Manages company-specific employee and owner relationships and group-health
 * coverage while preserving each Contact's primary company and other business relationships.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
public with sharing class EmployeeRosterService {

    private static final String GROUP_HEALTH_RT = 'Group_Health';
    private static final String CONTACT_INACTIVE = 'Inactive';
    private static final String CONTACT_ACTIVE = 'Active';
    private static final String INSURANCE_ACTIVE = 'Active';

    /**
     * @description Raised when an offboard request is empty or resolves to no employee relationship.
     */
    public class EmployeeOffboardException extends Exception {}

    /**
     * @description Raised when an onboard request cannot identify a person, company or valid policy.
     */
    public class EmployeeOnboardException extends Exception {}

    /**
     * @description Returns the active picklist options for the inline-editable relationship fields
     * (Roles and coverage tier), keyed 'roles' and 'family', each a list of {label, value} maps.
     * @return The picklist options for the editable columns.
     */
    public Map<String, List<Map<String, String>>> getFieldOptions() {
        return new Map<String, List<Map<String, String>>>{
            'roles' => picklistOptions(AccountContactRelation.Roles.getDescribe().getPicklistValues()),
            'family' => picklistOptions(AccountContactRelation.Family__c.getDescribe().getPicklistValues())
        };
    }

    /**
     * @description Maps active picklist entries to {label, value} option maps.
     * @param entries The picklist entries to map.
     * @return The active options.
     */
    private List<Map<String, String>> picklistOptions(List<Schema.PicklistEntry> entries) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{ 'label' => entry.getLabel(), 'value' => entry.getValue() });
            }
        }
        return options;
    }

    /**
     * @description Inbound inline edit for one employment relationship row.
     */
    public class RosterEdit {
        @AuraEnabled public Id acrId;
        @AuraEnabled public String roles;
        @AuraEnabled public String family;
    }

    /**
     * @description A group-health policy an employee of the company can be enrolled into, with the
     * coverage the policy carries so the enrolment form can pre-tick Dental and Vision.
     */
    public class PolicyOption {
        @AuraEnabled public Id policyId;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean withDental;
        @AuraEnabled public Boolean withVision;
    }

    /**
     * @description Inbound request to add one person to a company as an employee, optionally
     * enrolling them into one of the company's group-health policies in the same save. Either
     * `contactId` (an existing person) or the name fields (a new person) must be supplied.
     */
    public class OnboardRequest {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String koreanName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobilePhone;
        @AuraEnabled public String title;
        @AuraEnabled public String roles;
        @AuraEnabled public String family;
        @AuraEnabled public Boolean empStatus;
        @AuraEnabled public Id insuranceId;
        @AuraEnabled public Date coverageStartDate;
        @AuraEnabled public Boolean medical;
        @AuraEnabled public Boolean dental;
        @AuraEnabled public Boolean vision;
    }

    /**
     * @description Display model for one employee row in the roster datatable.
     */
    public class EmployeeRow {
        @AuraEnabled public Id acrId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String contactUrl;
        @AuraEnabled public String roles;
        @AuraEnabled public String plans;
        @AuraEnabled public String family;
        @AuraEnabled public Boolean activeIns;
        @AuraEnabled public Boolean empStatus;
        @AuraEnabled public String company;
        @AuraEnabled public Id companyId;
        @AuraEnabled public String companyUrl;
    }

    /**
     * @description Returns direct and additional company relationships, including inactive ones,
     * for a company and its descendants. A person related to several companies has one row per
     * company so roles, employment status and coverage remain specific to that relationship.
     * @param accountId The company account whose roster to list (root of the roll-up).
     * @return The employee rows, ordered by company then contact name.
     */
    public List<EmployeeRow> getRoster(Id accountId) {
        Set<Id> accountIds = collectHierarchy(accountId);
        List<AccountContactRelation> relations = [
            SELECT Id, ContactId, Contact.Name, Roles, Emp_Status__c, AccountId, Account.Name,
                   Family__c
            FROM AccountContactRelation
            WHERE AccountId IN :accountIds
            WITH USER_MODE
            ORDER BY Account.Name, Contact.Name
        ];

        Set<Id> contactIds = new Set<Id>();
        for (AccountContactRelation acr : relations) {
            contactIds.add(acr.ContactId);
        }
        Map<String, String> coverageByPair = summarizeCoverage(accountIds, contactIds);

        List<EmployeeRow> rows = new List<EmployeeRow>();
        for (AccountContactRelation acr : relations) {
            EmployeeRow row = new EmployeeRow();
            row.acrId = acr.Id;
            row.contactId = acr.ContactId;
            row.name = acr.Contact.Name;
            row.contactUrl = '/' + acr.ContactId;
            row.roles = acr.Roles;
            String key = pairKey(acr.AccountId, acr.ContactId);
            row.plans = coverageByPair.get(key);
            row.family = acr.Family__c;
            row.activeIns = coverageByPair.containsKey(key);
            row.empStatus = acr.Emp_Status__c;
            row.company = acr.Account.Name;
            row.companyId = acr.AccountId;
            row.companyUrl = '/' + acr.AccountId;
            rows.add(row);
        }
        return rows;
    }

    /**
     * @description Summarizes active group-health coverage separately for each company/contact
     * pair. Both the membership and its policy must be active.
     * @param accountIds The companies whose coverage to summarize.
     * @param contactIds The contacts to summarize.
     * @return Plan initials keyed by company/contact pair; uncovered pairs are absent.
     */
    private Map<String, String> summarizeCoverage(Set<Id> accountIds, Set<Id> contactIds) {
        Map<String, Set<String>> typesByPair = new Map<String, Set<String>>();
        for (ContactInsuranceAssociation__c cia : [
            SELECT Contact__c, Insurance__r.Company__c, Medical__c, Dental__c, Vision__c
            FROM ContactInsuranceAssociation__c
            WHERE Contact__c IN :contactIds
              AND Insurance__r.Company__c IN :accountIds
              AND Active__c = true
              AND Insurance__r.Status__c = :INSURANCE_ACTIVE
              AND Insurance__r.RecordType.DeveloperName = :GROUP_HEALTH_RT
            WITH USER_MODE
        ]) {
            String key = pairKey(cia.Insurance__r.Company__c, cia.Contact__c);
            Set<String> types = typesByPair.get(key);
            if (types == null) {
                types = new Set<String>();
                typesByPair.put(key, types);
            }
            if (cia.Medical__c) {
                types.add('M');
            }
            if (cia.Dental__c) {
                types.add('D');
            }
            if (cia.Vision__c) {
                types.add('V');
            }
        }

        Map<String, String> summaryByPair = new Map<String, String>();
        for (String key : typesByPair.keySet()) {
            List<String> ordered = new List<String>();
            for (String code : new List<String>{ 'M', 'D', 'V' }) {
                if (typesByPair.get(key).contains(code)) {
                    ordered.add(code);
                }
            }
            summaryByPair.put(key, String.join(ordered, ' / '));
        }
        return summaryByPair;
    }

    /**
     * @description Collects a company account and every descendant company in the account
     * hierarchy, so a parent's roster rolls up all sub-company employees. Bulk-safe and
     * cycle-safe (each account is visited once).
     * @param rootId The account to start the walk from.
     * @return The root account id plus every descendant account id.
     */
    private Set<Id> collectHierarchy(Id rootId) {
        Set<Id> accountIds = new Set<Id>{ rootId };
        Set<Id> frontier = new Set<Id>{ rootId };
        while (!frontier.isEmpty()) {
            List<Account> children = [
                SELECT Id FROM Account WHERE ParentId IN :frontier WITH USER_MODE
            ];
            frontier = new Set<Id>();
            for (Account child : children) {
                if (accountIds.add(child.Id)) {
                    frontier.add(child.Id);
                }
            }
        }
        return accountIds;
    }

    /**
     * @description Ends employment and group-health memberships only for the selected company/
     * contact pairs. A Contact becomes inactive only when no other employed relationship remains.
     * @param acrIds The AccountContactRelation ids to offboard.
     * @param endDate The coverage end date to stamp on the junctions; defaults to today when null.
     */
    public void offboard(Set<Id> acrIds, Date endDate) {
        if (acrIds == null || acrIds.isEmpty()) {
            throw new EmployeeOffboardException('No employee was selected to offboard.');
        }
        Date effectiveEnd = endDate == null ? Date.today() : endDate;

        Map<Id, AccountContactRelation> acrById = new Map<Id, AccountContactRelation>([
            SELECT Id, AccountId, ContactId
            FROM AccountContactRelation
            WHERE Id IN :acrIds
            WITH USER_MODE
        ]);
        if (acrById.isEmpty()) {
            throw new EmployeeOffboardException('The selected employee relationship no longer exists.');
        }

        Set<Id> contactIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<String> selectedPairs = new Set<String>();
        for (AccountContactRelation acr : acrById.values()) {
            contactIds.add(acr.ContactId);
            accountIds.add(acr.AccountId);
            selectedPairs.add(pairKey(acr.AccountId, acr.ContactId));
        }

        List<ContactInsuranceAssociation__c> coverageToEnd = new List<ContactInsuranceAssociation__c>();
        for (ContactInsuranceAssociation__c cia : [
            SELECT Id, Contact__c, Insurance__r.Company__c
            FROM ContactInsuranceAssociation__c
            WHERE Contact__c IN :contactIds
              AND Insurance__r.Company__c IN :accountIds
              AND Active__c = true
              AND Insurance__r.RecordType.DeveloperName = :GROUP_HEALTH_RT
            WITH USER_MODE
        ]) {
            if (selectedPairs.contains(pairKey(cia.Insurance__r.Company__c, cia.Contact__c))) {
                coverageToEnd.add(new ContactInsuranceAssociation__c(
                    Id = cia.Id, Coverage_End_Date__c = effectiveEnd, Active__c = false
                ));
            }
        }

        List<AccountContactRelation> employmentUpdates = new List<AccountContactRelation>();
        for (Id acrId : acrById.keySet()) {
            employmentUpdates.add(new AccountContactRelation(Id = acrId, Emp_Status__c = false));
        }

        Set<Id> stillEmployed = new Set<Id>();
        for (AccountContactRelation remaining : [
            SELECT ContactId FROM AccountContactRelation
            WHERE ContactId IN :contactIds AND Id NOT IN :acrIds AND Emp_Status__c = true
            WITH USER_MODE
        ]) {
            stillEmployed.add(remaining.ContactId);
        }
        List<Contact> contactUpdates = new List<Contact>();
        for (Id contactId : contactIds) {
            if (!stillEmployed.contains(contactId)) {
                contactUpdates.add(new Contact(Id = contactId, Status__c = CONTACT_INACTIVE));
            }
        }

        if (!coverageToEnd.isEmpty()) {
            Database.update(coverageToEnd, AccessLevel.USER_MODE);
        }
        Database.update(employmentUpdates, AccessLevel.USER_MODE);
        if (!contactUpdates.isEmpty()) {
            Database.update(contactUpdates, AccessLevel.USER_MODE);
        }
    }

    /**
     * @description Applies inline edits to the Roles and coverage-tier (Family) fields on the
     * given employment relationships. Bulk-safe, user-mode DML.
     * @param edits The relationship rows to update.
     */
    public void saveRelationships(List<RosterEdit> edits) {
        if (edits == null || edits.isEmpty()) {
            return;
        }
        List<AccountContactRelation> updates = new List<AccountContactRelation>();
        for (RosterEdit edit : edits) {
            if (edit.acrId == null) {
                continue;
            }
            updates.add(new AccountContactRelation(
                Id = edit.acrId,
                Roles = edit.roles,
                Family__c = edit.family
            ));
        }
        if (!updates.isEmpty()) {
            Database.update(updates, AccessLevel.USER_MODE);
        }
    }

    /**
     * @description Lists the company's active group-health policies an employee can be enrolled
     * into, newest term first, labelled for a picklist.
     * @param accountId The company account whose policies to offer.
     * @return One option per active group-health policy; empty when the company has none.
     */
    public List<PolicyOption> getGroupHealthPolicies(Id accountId) {
        List<PolicyOption> options = new List<PolicyOption>();
        if (accountId == null) {
            return options;
        }
        for (Insurance__c policy : [
            SELECT Id, Name, Insurance_Provider__r.Name, Insurance_Start_Date__c, Insurance_End_Date__c,
                   With_Dental__c, With_Vision__c
            FROM Insurance__c
            WHERE Company__c = :accountId
              AND Status__c = :INSURANCE_ACTIVE
              AND RecordType.DeveloperName = :GROUP_HEALTH_RT
            WITH USER_MODE
            ORDER BY Insurance_Start_Date__c DESC NULLS LAST
        ]) {
            PolicyOption option = new PolicyOption();
            option.policyId = policy.Id;
            option.label = buildPolicyLabel(policy);
            option.withDental = policy.With_Dental__c;
            option.withVision = policy.With_Vision__c;
            options.add(option);
        }
        return options;
    }

    /**
     * @description Builds the display label for a group-health policy option: policy name, carrier,
     * and the policy term.
     * @param policy The policy to label.
     * @return The option label.
     */
    private String buildPolicyLabel(Insurance__c policy) {
        List<String> parts = new List<String>{ policy.Name };
        if (policy.Insurance_Provider__r != null && String.isNotBlank(policy.Insurance_Provider__r.Name)) {
            parts.add(policy.Insurance_Provider__r.Name);
        }
        if (policy.Insurance_Start_Date__c != null) {
            // Date.format() renders in the running user's locale; string concatenation of a Date
            // would append a 00:00:00 time component.
            String term = policy.Insurance_Start_Date__c.format();
            if (policy.Insurance_End_Date__c != null) {
                term += ' ~ ' + policy.Insurance_End_Date__c.format();
            }
            parts.add(term);
        }
        return String.join(parts, ' — ');
    }

    /**
     * @description Adds people to companies without replacing existing primary companies, reuses
     * existing relationships and active memberships, and creates missing ones in user mode.
     * Any failure rolls back the whole batch.
     * @param requests The people to onboard.
     * @return The contact id per request, in request order.
     */
    public List<Id> onboard(List<OnboardRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            throw new EmployeeOnboardException('No employee was submitted.');
        }
        for (OnboardRequest req : requests) {
            validateOnboard(req);
        }

        Savepoint restorePoint = Database.setSavepoint();
        try {
            List<Id> contactIds = resolveContacts(requests);
            applyEmployment(requests, contactIds);
            createCoverage(requests, contactIds);
            return contactIds;
        } catch (Exception ex) {
            Database.rollback(restorePoint);
            throw ex;
        }
    }

    /**
     * @description Rejects an onboard request that cannot identify the company or the person.
     * @param req The request to check.
     */
    private void validateOnboard(OnboardRequest req) {
        if (req == null || req.accountId == null) {
            throw new EmployeeOnboardException('The company is missing from this request.');
        }
        if (req.contactId == null && String.isBlank(req.lastName)) {
            throw new EmployeeOnboardException('Enter a last name, or pick an existing contact.');
        }
    }

    /**
     * @description Resolves new and existing Contacts, filling a primary company only when blank.
     * A Contact requested for several companies keeps the first primary company assigned.
     * @param requests The onboard requests, in order.
     * @return The contact id per request, in request order.
     */
    private List<Id> resolveContacts(List<OnboardRequest> requests) {
        List<Contact> toInsert = new List<Contact>();
        List<Integer> insertPositions = new List<Integer>();
        Set<Id> existingIds = new Set<Id>();

        for (Integer i = 0; i < requests.size(); i++) {
            OnboardRequest req = requests[i];
            if (req.contactId == null) {
                toInsert.add(new Contact(
                    FirstName = req.firstName,
                    LastName = req.lastName,
                    Korean_Name__c = req.koreanName,
                    Email = req.email,
                    MobilePhone = req.mobilePhone,
                    Title = req.title,
                    AccountId = req.accountId,
                    Status__c = CONTACT_ACTIVE
                ));
                insertPositions.add(i);
            } else {
                existingIds.add(req.contactId);
            }
        }

        Map<Id, Contact> existingById = new Map<Id, Contact>([
            SELECT Id, AccountId, Status__c
            FROM Contact
            WHERE Id IN :existingIds
            WITH USER_MODE
        ]);

        Map<Id, Contact> toUpdate = new Map<Id, Contact>();
        for (OnboardRequest req : requests) {
            if (req.contactId == null) {
                continue;
            }
            Contact person = existingById.get(req.contactId);
            if (person == null) {
                throw new EmployeeOnboardException('The selected contact no longer exists.');
            }
            if (person.AccountId == null || person.Status__c != CONTACT_ACTIVE) {
                Contact changed = new Contact(Id = person.Id, Status__c = CONTACT_ACTIVE);
                if (person.AccountId == null) {
                    changed.AccountId = req.accountId;
                    person.AccountId = req.accountId;
                }
                person.Status__c = CONTACT_ACTIVE;
                toUpdate.put(person.Id, changed);
            }
        }

        if (!toInsert.isEmpty()) {
            // Setting AccountId here is what creates each direct AccountContactRelation.
            Database.insert(toInsert, AccessLevel.USER_MODE);
        }
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate.values(), AccessLevel.USER_MODE);
        }

        List<Id> contactIds = new List<Id>();
        for (OnboardRequest req : requests) {
            contactIds.add(req.contactId);
        }
        for (Integer position = 0; position < insertPositions.size(); position++) {
            contactIds.set(insertPositions[position], toInsert[position].Id);
        }
        return contactIds;
    }

    /**
     * @description Reuses direct or indirect company/contact relationships and creates missing
     * indirect ones. Unspecified roles and coverage tiers retain their existing values.
     * @param requests The onboard requests, in order.
     * @param contactIds The resolved contact id per request, in the same order.
     */
    private void applyEmployment(List<OnboardRequest> requests, List<Id> contactIds) {
        Set<Id> accountIds = new Set<Id>();
        for (OnboardRequest req : requests) {
            accountIds.add(req.accountId);
        }

        Map<String, AccountContactRelation> relationByPair = new Map<String, AccountContactRelation>();
        for (AccountContactRelation relation : [
            SELECT Id, AccountId, ContactId
            FROM AccountContactRelation
            WHERE AccountId IN :accountIds AND ContactId IN :contactIds
            WITH USER_MODE
        ]) {
            relationByPair.put(pairKey(relation.AccountId, relation.ContactId), relation);
        }

        Map<String, AccountContactRelation> changesByPair = new Map<String, AccountContactRelation>();
        for (Integer i = 0; i < requests.size(); i++) {
            OnboardRequest req = requests[i];
            String key = pairKey(req.accountId, contactIds[i]);
            AccountContactRelation change = changesByPair.get(key);
            if (change == null) {
                AccountContactRelation existing = relationByPair.get(key);
                change = existing == null
                    ? new AccountContactRelation(AccountId = req.accountId, ContactId = contactIds[i])
                    : new AccountContactRelation(Id = existing.Id);
                changesByPair.put(key, change);
            }
            if (String.isNotBlank(req.roles)) {
                change.Roles = req.roles;
            }
            if (String.isNotBlank(req.family)) {
                change.Family__c = req.family;
            }
            change.Emp_Status__c = req.empStatus == null ? true : req.empStatus;
        }
        List<AccountContactRelation> inserts = new List<AccountContactRelation>();
        List<AccountContactRelation> updates = new List<AccountContactRelation>();
        for (AccountContactRelation change : changesByPair.values()) {
            if (change.Id == null) {
                inserts.add(change);
            } else {
                updates.add(change);
            }
        }
        if (!inserts.isEmpty()) {
            Database.insert(inserts, AccessLevel.USER_MODE);
        }
        if (!updates.isEmpty()) {
            Database.update(updates, AccessLevel.USER_MODE);
        }
    }

    /**
     * @description Creates missing active memberships only for active group-health policies of
     * the requested company. Existing active memberships retain their dates and coverage choices.
     * @param requests The onboard requests, in order.
     * @param contactIds The resolved contact id per request, in the same order.
     */
    private void createCoverage(List<OnboardRequest> requests, List<Id> contactIds) {
        Set<Id> policyIds = new Set<Id>();
        for (OnboardRequest req : requests) {
            if (req.insuranceId != null) {
                policyIds.add(req.insuranceId);
            }
        }
        if (policyIds.isEmpty()) {
            return;
        }
        Map<Id, Insurance__c> policiesById = new Map<Id, Insurance__c>([
            SELECT Id, Company__c FROM Insurance__c
            WHERE Id IN :policyIds AND Status__c = :INSURANCE_ACTIVE
              AND RecordType.DeveloperName = :GROUP_HEALTH_RT
            WITH USER_MODE
        ]);
        Set<String> activeMemberships = new Set<String>();
        for (ContactInsuranceAssociation__c existing : [
            SELECT Insurance__c, Contact__c FROM ContactInsuranceAssociation__c
            WHERE Insurance__c IN :policyIds AND Contact__c IN :contactIds AND Active__c = true
            WITH USER_MODE
        ]) {
            activeMemberships.add(pairKey(existing.Insurance__c, existing.Contact__c));
        }
        List<ContactInsuranceAssociation__c> coverage = new List<ContactInsuranceAssociation__c>();
        for (Integer i = 0; i < requests.size(); i++) {
            OnboardRequest req = requests[i];
            if (req.insuranceId == null) {
                continue;
            }
            Insurance__c policy = policiesById.get(req.insuranceId);
            if (policy == null || policy.Company__c != req.accountId) {
                throw new EmployeeOnboardException(Label.EmployeeRoster_InvalidCompanyPolicy);
            }
            if (!activeMemberships.add(pairKey(req.insuranceId, contactIds[i]))) {
                continue;
            }
            coverage.add(new ContactInsuranceAssociation__c(
                Contact__c = contactIds[i],
                Insurance__c = req.insuranceId,
                Coverage_Start_Date__c = req.coverageStartDate == null ? Date.today() : req.coverageStartDate,
                Active__c = true,
                Medical__c = req.medical == true,
                Dental__c = req.dental == true,
                Vision__c = req.vision == true
            ));
        }
        if (!coverage.isEmpty()) {
            Database.insert(coverage, AccessLevel.USER_MODE);
        }
    }

    /**
     * @description Builds a composite key for a company or policy and a Contact.
     * @param parentId The company account or insurance policy id.
     * @param contactId The contact id.
     * @return The composite key.
     */
    private String pairKey(Id parentId, Id contactId) {
        return String.valueOf(parentId) + ':' + String.valueOf(contactId);
    }
}
