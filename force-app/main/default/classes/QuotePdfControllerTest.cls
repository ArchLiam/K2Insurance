/**
 * @description Test class for QuotePdfController.
 * Note: PageReference.getContentAsPDF() is unavailable in test context, so
 * QuotePdfController short-circuits to a test stub blob when Test.isRunningTest()
 * is true. These tests verify the surrounding behaviour (validation, persistence,
 * email send) rather than the rendered PDF bytes themselves.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@IsTest
private class QuotePdfControllerTest {

    private static Quote createQuoteWithOpportunity() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        Contact con = new Contact(
            FirstName = 'Jane',
            LastName = 'Doe',
            Email = 'jane.doe@example.com',
            Phone = '555-0100',
            AccountId = acct.Id
        );
        insert con;

        Pricebook2 pb = new Pricebook2(Id = Test.getStandardPricebookId());
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Renewal Identified',
            CloseDate = Date.today().addDays(30),
            AccountId = acct.Id,
            Pricebook2Id = pb.Id
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            ContactId = con.Id,
            Email = 'jane.doe@example.com',
            Plan_Name__c = 'Gold Plan',
            Proposed_Premium__c = 1234.56,
            Proposed_Start_Date__c = Date.today().addDays(30),
            Proposed_Term_months__c = 12,
            Pricebook2Id = pb.Id
        );
        insert q;
        return q;
    }

    @IsTest
    static void generatePdf_withValidQuote_returnsBase64() {
        Quote q = createQuoteWithOpportunity();

        Test.startTest();
        QuotePdfController.PdfResult result = QuotePdfController.generatePdf(q.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Expected a PdfResult');
        Assert.isNotNull(result.base64, 'Expected base64 content');
        Assert.isTrue(result.fileName.endsWith('.pdf'), 'Filename should end in .pdf');
        Assert.isTrue(result.sizeBytes > 0, 'Size should be positive');
    }

    @IsTest
    static void generatePdf_nullId_throws() {
        Boolean thrown = false;
        Test.startTest();
        try {
            QuotePdfController.generatePdf(null);
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown, 'Expected AuraHandledException for null Quote Id');
    }

    @IsTest
    static void saveToQuote_attachesContentVersion() {
        Quote q = createQuoteWithOpportunity();

        Test.startTest();
        QuotePdfController.SaveResult result = QuotePdfController.saveToQuote(q.Id);
        Test.stopTest();

        Assert.isNotNull(result.contentVersionId, 'Expected a ContentVersion Id');
        Assert.isNotNull(result.contentDocumentId, 'Expected a ContentDocument Id');

        Integer linkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :q.Id
            AND ContentDocumentId = :result.contentDocumentId
        ];
        Assert.areEqual(1, linkCount, 'Expected ContentDocument linked to Quote');
    }

    @IsTest
    static void saveToQuote_nullId_throws() {
        Boolean thrown = false;
        Test.startTest();
        try {
            QuotePdfController.saveToQuote(null);
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown, 'Expected AuraHandledException for null Quote Id');
    }

    @IsTest
    static void saveAndEmail_sendsEmailWithAttachment() {
        Quote q = createQuoteWithOpportunity();

        Test.startTest();
        QuotePdfController.SaveResult result = QuotePdfController.saveAndEmail(
            q.Id,
            'recipient@example.com',
            'Your K2 Insurance Quote',
            '<p>Please review the attached quote.</p>',
            null
        );
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.isNotNull(result.contentVersionId);
        Assert.areEqual(1, invocations, 'Expected one email send');
    }

    @IsTest
    static void saveAndEmail_blankToAddress_throws() {
        Quote q = createQuoteWithOpportunity();
        Boolean thrown = false;

        Test.startTest();
        try {
            QuotePdfController.saveAndEmail(q.Id, '', 'Subj', '<p>Body</p>', null);
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }

    @IsTest
    static void saveAndEmail_blankSubject_throws() {
        Quote q = createQuoteWithOpportunity();
        Boolean thrown = false;

        Test.startTest();
        try {
            QuotePdfController.saveAndEmail(q.Id, 'r@example.com', '', '<p>Body</p>', null);
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }

    @IsTest
    static void saveAndEmail_nullQuoteId_throws() {
        Boolean thrown = false;
        Test.startTest();
        try {
            QuotePdfController.saveAndEmail(null, 'r@example.com', 'Subj', '<p>x</p>', null);
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        Assert.isTrue(thrown);
    }
}