/**
 * @description Shared test-data factory for the Employee Roster tests: builds a company with a
 * group-health policy and N active employees, each on an active coverage junction.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@isTest
public with sharing class EmployeeRosterTestData {

    /**
     * @description Builds a company account, a Group Health policy, and the requested number of
     * active employees each linked to the company (Emp.Status = true) and holding active coverage.
     * @param employeeCount How many employees (relationships and coverage junctions) to create.
     * @return The created AccountContactRelation records.
     */
    public static List<AccountContactRelation> buildRoster(Integer employeeCount) {
        Map<String, Id> accountRt = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName IN ('Client_Business', 'Insurance_Provider')
        ]) {
            accountRt.put(rt.DeveloperName, rt.Id);
        }

        Account company = new Account(Name = 'Roster Test Co', RecordTypeId = accountRt.get('Client_Business'));
        Account carrier = new Account(Name = 'Roster Test Carrier', RecordTypeId = accountRt.get('Insurance_Provider'));
        insert new List<Account>{ company, carrier };

        Contact holder = new Contact(LastName = 'Roster Holder', Status__c = 'Active');
        insert holder;

        Id groupHealthRt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Insurance__c' AND DeveloperName = 'Group_Health'
            LIMIT 1
        ].Id;
        Insurance__c policy = new Insurance__c(
            Name = 'ROSTER-GH-TEST',
            RecordTypeId = groupHealthRt,
            Company__c = company.Id,
            Insurance_Provider__c = carrier.Id,
            Policy_Holder__c = holder.Id,
            Status__c = 'Active',
            Insurance_Start_Date__c = Date.today().addMonths(-2),
            Insurance_Term_months__c = 12
        );
        insert policy;

        List<Contact> employees = new List<Contact>();
        for (Integer i = 0; i < employeeCount; i++) {
            employees.add(new Contact(LastName = 'Roster Emp ' + i, Status__c = 'Active', AccountId = company.Id));
        }
        insert employees; // Salesforce auto-creates the direct AccountContactRelation for each.

        Set<Id> employeeIds = new Map<Id, Contact>(employees).keySet();
        List<AccountContactRelation> relations = [
            SELECT Id, AccountId, ContactId FROM AccountContactRelation
            WHERE AccountId = :company.Id AND ContactId IN :employeeIds
        ];
        for (AccountContactRelation relation : relations) {
            relation.Emp_Status__c = true;
            relation.Roles = 'Employee';
        }
        update relations;

        List<ContactInsuranceAssociation__c> coverage = new List<ContactInsuranceAssociation__c>();
        for (Contact employee : employees) {
            coverage.add(new ContactInsuranceAssociation__c(
                Contact__c = employee.Id,
                Insurance__c = policy.Id,
                Active__c = true,
                Medical__c = true
            ));
        }
        insert coverage;
        return relations;
    }

    /**
     * @description Two-business fixture with shared Contacts, separate policies and relationships.
     * @author Liam Jeong <liam.jeong@5sinfusion.com>
     */
    public class MultiBusinessRoster {
        public Id primaryCompanyId;
        public Id otherCompanyId;
        public Id primaryPolicyId;
        public Id otherPolicyId;
        public Set<Id> contactIds = new Set<Id>();
        public List<AccountContactRelation> primaryRelations;
        public List<AccountContactRelation> otherRelations = new List<AccountContactRelation>();
    }

    /**
     * @description Builds two businesses whose relationships and coverage can share Contacts.
     * @param employeeCount Number of Contacts at the primary company.
     * @param relatedCount Number also linked as Owners at the other company.
     * @param withCoverage Whether those additional relationships have Dental coverage.
     * @return The synthetic companies, policies, Contacts and relationships.
     */
    public static MultiBusinessRoster buildMultiBusinessRoster(
        Integer employeeCount, Integer relatedCount, Boolean withCoverage
    ) {
        MultiBusinessRoster data = new MultiBusinessRoster();
        data.primaryRelations = buildRoster(employeeCount);
        data.primaryCompanyId = data.primaryRelations[0].AccountId;
        Account primary = [SELECT RecordTypeId FROM Account WHERE Id = :data.primaryCompanyId];
        Account other = new Account(Name = 'Roster Additional Business', RecordTypeId = primary.RecordTypeId);
        insert other;
        data.otherCompanyId = other.Id;

        Insurance__c primaryPolicy = [
            SELECT Name, RecordTypeId, Company__c, Insurance_Provider__c, Policy_Holder__c,
                   Status__c, Insurance_Start_Date__c, Insurance_Term_months__c
            FROM Insurance__c WHERE Company__c = :data.primaryCompanyId LIMIT 1
        ];
        data.primaryPolicyId = primaryPolicy.Id;
        Insurance__c otherPolicy = primaryPolicy.clone(false, false, false, false);
        otherPolicy.Name = 'ROSTER-ADDITIONAL-GH-TEST';
        otherPolicy.Company__c = other.Id;
        insert otherPolicy;
        data.otherPolicyId = otherPolicy.Id;

        List<ContactInsuranceAssociation__c> coverage = new List<ContactInsuranceAssociation__c>();
        for (Integer i = 0; i < data.primaryRelations.size(); i++) {
            Id contactId = data.primaryRelations[i].ContactId;
            data.contactIds.add(contactId);
            if (i < relatedCount) {
                data.otherRelations.add(new AccountContactRelation(
                    AccountId = other.Id, ContactId = contactId, Roles = 'Owner',
                    Family__c = 'EF', Emp_Status__c = true
                ));
                if (withCoverage) {
                    coverage.add(new ContactInsuranceAssociation__c(
                        Contact__c = contactId, Insurance__c = otherPolicy.Id,
                        Active__c = true, Medical__c = false, Dental__c = true,
                        Coverage_Start_Date__c = Date.today().addDays(-10)
                    ));
                }
            }
        }
        if (!data.otherRelations.isEmpty()) {
            insert data.otherRelations;
        }
        if (!coverage.isEmpty()) {
            insert coverage;
        }
        return data;
    }

    /**
     * @description Creates a minimum-access user for CRUD/FLS rejection tests.
     * @return The synthetic user without roster permissions.
     */
    public static User createRestrictedUser() {
        Id profileId = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1].Id;
        User restricted = new User(
            ProfileId = profileId, Username = 'roster.' + Crypto.getRandomLong() + '@example.invalid',
            Email = 'roster@example.invalid', LastName = 'Roster Restricted', Alias = 'roster',
            TimeZoneSidKey = 'America/Chicago', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert restricted;
        }
        return restricted;
    }

    /**
     * @description Creates a sub-company under the given parent account and one active employee on
     * it, for exercising the roster's account-hierarchy roll-up.
     * @param parentAccountId The parent company the sub-company reports to.
     * @param childName The sub-company name.
     * @return The sub-company employee's AccountContactRelation.
     */
    public static AccountContactRelation addChildCompanyEmployee(Id parentAccountId, String childName) {
        Id clientRt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'Client_Business'
            LIMIT 1
        ].Id;
        Account child = new Account(Name = childName, RecordTypeId = clientRt, ParentId = parentAccountId);
        insert child;

        Contact employee = new Contact(LastName = childName + ' Emp', Status__c = 'Active', AccountId = child.Id);
        insert employee; // Salesforce auto-creates the direct AccountContactRelation.

        AccountContactRelation acr = [
            SELECT Id FROM AccountContactRelation
            WHERE AccountId = :child.Id AND ContactId = :employee.Id
            LIMIT 1
        ];
        acr.Emp_Status__c = true;
        acr.Roles = 'Employee';
        update acr;
        return acr;
    }
}
