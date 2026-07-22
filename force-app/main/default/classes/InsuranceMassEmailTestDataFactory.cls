/**
 * @description Test data provider for the Insurance Mass Email tests. Reads existing org data
 * (EmailTemplate, Insurance__c with/without a Policy Holder email) used by the SeeAllData tests.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@IsTest
public with sharing class InsuranceMassEmailTestDataFactory {

    /**
     * @description Returns the Id of one existing EmailTemplate (requires at least one in the org).
     * @return Id of an EmailTemplate.
     */
    public static Id getExistingEmailTemplateId() {
        EmailTemplate templateRecord = [
            SELECT Id
            FROM EmailTemplate
            LIMIT 1
        ];
        return templateRecord.Id;
    }

    /**
     * @description Returns one Insurance__c whose Policy Holder has an email address.
     * @return Insurance__c record, or null if none exist.
     */
    public static Insurance__c getExistingInsuranceWithEmail() {
        return [
            SELECT Id,
                   Name,
                   Policy_Holder__c,
                   Policy_Holder__r.Email
            FROM Insurance__c
            WHERE Policy_Holder__c != null
              AND Policy_Holder__r.Email != null
            LIMIT 1
        ];
    }

    /**
     * @description Returns one Insurance__c that has a Policy Holder but no email on the Contact.
     * @return Insurance__c record, or null if none exist.
     */
    public static Insurance__c getExistingInsuranceWithoutEmail() {
        List<Insurance__c> rows = [
            SELECT Id,
                   Name,
                   Policy_Holder__c,
                   Policy_Holder__r.Email
            FROM Insurance__c
            WHERE Policy_Holder__c != null
              AND Policy_Holder__r.Email = null
            LIMIT 1
        ];

        return rows.isEmpty() ? null : rows[0];
    }

    /**
     * @description Returns up to limitSize Insurance__c records that have a Policy Holder.
     * @param limitSize Maximum number of records to return.
     * @return List of Insurance__c records.
     */
    public static List<Insurance__c> getExistingInsuranceList(Integer limitSize) {
        return [
            SELECT Id,
                   Name,
                   Policy_Holder__c,
                   Policy_Holder__r.Email
            FROM Insurance__c
            WHERE Policy_Holder__c != null
            LIMIT :limitSize
        ];
    }
}
