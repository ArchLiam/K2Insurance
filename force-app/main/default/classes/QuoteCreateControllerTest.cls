/**
 * @description Test class for QuoteCreateController.
 * @author Liam Jeong (liam.jeong@5sinfusion.com)
 * @date 2026-05-23
 */
@IsTest
private class QuoteCreateControllerTest {

    private static Account insertProvider() {
        Id rtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Insurance_Provider')
            .getRecordTypeId();
        Account a = new Account(Name = 'Test Provider', RecordTypeId = rtId);
        insert a;
        return a;
    }

    private static Opportunity insertOpportunity(Id accountId, Id contactId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Renewal',
            StageName = 'Renewal Identified',
            CloseDate = Date.today().addDays(30),
            AccountId = accountId
        );
        if (contactId != null) {
            // ContactId not directly settable on Opportunity; left as future work.
        }
        insert opp;
        return opp;
    }

    @IsTest
    static void createQuote_validInputs_insertsQuote() {
        Account provider = insertProvider();
        Opportunity opp = insertOpportunity(provider.Id, null);

        Test.startTest();
        QuoteCreateController.CreateResult result = QuoteCreateController.createQuote(
            opp.Id,
            provider.Id,
            'Gold Plan',
            1234.56,
            Date.today().addDays(30),
            12,
            'Test description'
        );
        Test.stopTest();

        Assert.isNotNull(result.quoteId, 'Expected a Quote Id');
        Assert.isTrue(result.quoteName.startsWith('Quote - Test Provider - '),
            'Expected auto-generated Name, got: ' + result.quoteName);

        Quote saved = [
            SELECT Id, Name, OpportunityId, Insurance_Provider__c,
                   Plan_Name__c, Proposed_Premium__c, Proposed_Start_Date__c,
                   Proposed_Term_months__c, Description, Status
            FROM Quote
            WHERE Id = :result.quoteId
        ];
        Assert.areEqual(opp.Id, saved.OpportunityId);
        Assert.areEqual(provider.Id, saved.Insurance_Provider__c);
        Assert.areEqual('Gold Plan', saved.Plan_Name__c);
        Assert.areEqual(1234.56, saved.Proposed_Premium__c);
        Assert.areEqual(Date.today().addDays(30), saved.Proposed_Start_Date__c);
        Assert.areEqual(12, saved.Proposed_Term_months__c);
        Assert.areEqual('Test description', saved.Description);
        Assert.areEqual('Draft', saved.Status);
    }

    @IsTest
    static void createQuote_minimalInputs_insertsQuote() {
        Account provider = insertProvider();
        Opportunity opp = insertOpportunity(provider.Id, null);

        Test.startTest();
        QuoteCreateController.CreateResult result = QuoteCreateController.createQuote(
            opp.Id, provider.Id, null, 100, Date.today().addDays(10), 6, null
        );
        Test.stopTest();

        Assert.isNotNull(result.quoteId);
    }

    @IsTest
    static void createQuote_nullOpportunity_throws() {
        Account provider = insertProvider();
        Boolean thrown = false;
        Test.startTest();
        try {
            QuoteCreateController.createQuote(
                null, provider.Id, 'p', 1, Date.today(), 12, 'd'
            );
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }

    @IsTest
    static void createQuote_nullProvider_throws() {
        Account provider = insertProvider();
        Opportunity opp = insertOpportunity(provider.Id, null);
        Boolean thrown = false;
        Test.startTest();
        try {
            QuoteCreateController.createQuote(
                opp.Id, null, 'p', 1, Date.today(), 12, 'd'
            );
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }

    @IsTest
    static void createQuote_nullPremium_throws() {
        Account provider = insertProvider();
        Opportunity opp = insertOpportunity(provider.Id, null);
        Boolean thrown = false;
        Test.startTest();
        try {
            QuoteCreateController.createQuote(
                opp.Id, provider.Id, 'p', null, Date.today(), 12, 'd'
            );
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }

    @IsTest
    static void createQuote_nullStartDate_throws() {
        Account provider = insertProvider();
        Opportunity opp = insertOpportunity(provider.Id, null);
        Boolean thrown = false;
        Test.startTest();
        try {
            QuoteCreateController.createQuote(
                opp.Id, provider.Id, 'p', 1, null, 12, 'd'
            );
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }

    @IsTest
    static void createQuote_nullTerm_throws() {
        Account provider = insertProvider();
        Opportunity opp = insertOpportunity(provider.Id, null);
        Boolean thrown = false;
        Test.startTest();
        try {
            QuoteCreateController.createQuote(
                opp.Id, provider.Id, 'p', 1, Date.today(), null, 'd'
            );
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }

    @IsTest
    static void createQuote_invalidOpportunity_throws() {
        Account provider = insertProvider();
        Boolean thrown = false;
        Id fakeOppId = '006000000000001AAA';
        Test.startTest();
        try {
            QuoteCreateController.createQuote(
                fakeOppId, provider.Id, 'p', 1, Date.today(), 12, 'd'
            );
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }
}
