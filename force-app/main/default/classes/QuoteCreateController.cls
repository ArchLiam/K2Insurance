/**
 * @description Creates a Quote on a Renewal Opportunity from a small set of
 * inputs (Insurance Provider, Plan Name, Proposed Premium, Description). Used
 * by the quickCreateQuote LWC which is exposed as a Quick Action on the
 * Opportunity record page. Sets Quote.Name explicitly so the schema-level
 * Required constraint doesn't block creation (Salesforce platform forces
 * Quote.Name to remain Required regardless of layout/AutoNumber settings).
 * @author Liam Jeong (liam.jeong@5sinfusion.com)
 * @date 2026-05-23
 */
public with sharing class QuoteCreateController {

    /** Response DTO — Id and Name of the new Quote, returned for navigation. */
    public class CreateResult {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
    }

    /**
     * @description Inserts a Quote against the supplied Renewal Opportunity.
     * @param opportunityId       Opportunity (Renewal) Id — required
     * @param insuranceProviderId Account Id (Insurance Provider RT)
     * @param planName            Plan Name (Quote.Plan_Name__c)
     * @param proposedPremium     Proposed Premium amount (Quote.Proposed_Premium__c)
     * @param description         Optional Description
     * @return CreateResult with the new Quote's Id and Name
     */
    @AuraEnabled
    public static CreateResult createQuote(
        Id opportunityId,
        Id insuranceProviderId,
        String planName,
        Decimal proposedPremium,
        String description
    ) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        if (insuranceProviderId == null) {
            throw new AuraHandledException('Insurance Provider is required.');
        }

        Opportunity opp = loadOpportunity(opportunityId);
        Pricebook2 pb = loadStandardPricebook();
        String providerName = loadAccountName(insuranceProviderId);

        Quote q = new Quote();
        q.OpportunityId = opportunityId;
        q.Pricebook2Id = pb.Id;
        q.Insurance_Provider__c = insuranceProviderId;
        q.Status = 'Draft';
        q.Name = buildQuoteName(providerName);

        if (String.isNotBlank(planName)) {
            q.Plan_Name__c = planName;
        }
        if (proposedPremium != null) {
            q.Proposed_Premium__c = proposedPremium;
        }
        if (String.isNotBlank(description)) {
            q.Description = description;
        }
        if (opp.ContactId != null) {
            q.ContactId = opp.ContactId;
        }

        insert q;

        CreateResult result = new CreateResult();
        result.quoteId = q.Id;
        result.quoteName = q.Name;
        return result;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static Opportunity loadOpportunity(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT Id, Name, ContactId, AccountId
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw new AuraHandledException('Opportunity not found.');
        }
        return opps[0];
    }

    private static Pricebook2 loadStandardPricebook() {
        if (Test.isRunningTest()) {
            return new Pricebook2(Id = Test.getStandardPricebookId());
        }
        List<Pricebook2> books = [
            SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1
        ];
        if (books.isEmpty()) {
            throw new AuraHandledException(
                'Standard Pricebook is not active. Activate it in Setup.'
            );
        }
        return books[0];
    }

    private static String loadAccountName(Id accountId) {
        for (Account a : [SELECT Name FROM Account WHERE Id = :accountId LIMIT 1]) {
            return a.Name;
        }
        return 'Unknown Provider';
    }

    private static String buildQuoteName(String providerName) {
        Date today = Date.today();
        String dateText =
            today.year() + '-' +
            String.valueOf(today.month()).leftPad(2, '0') + '-' +
            String.valueOf(today.day()).leftPad(2, '0');
        return 'Quote - ' + providerName + ' - ' + dateText;
    }
}
