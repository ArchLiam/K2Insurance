/**
 * @description Verifies statement selection, reconciliation, File versioning, and access controls.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@isTest
private class AgentPayoutPdfServiceTest {
    /** @description Creates synthetic settled records shared by the test methods. */
    @testSetup
    static void setup() { AgentPayoutPdfTestData.createPayout(); }

    /** @description Returns the scenario identifier without relying on a production record. @return The payout id. */
    private static Id payoutId() { return [SELECT Id FROM Agent_Payout__c LIMIT 1].Id; }

    /** @description Preserves computed shares, includes only stamped lines, and avoids hyperlink formulas. */
    @isTest
    static void readsTheExactPayoutAndDetectsChangedDetails() {
        Id id = payoutId();
        Test.startTest();
        AgentPayoutPdfService.Statement statement = AgentPayoutPdfService.readStatements(new Set<Id>{ id }).get(id);
        Test.stopTest();
        Assert.areEqual(20, statement.details.size(), 'Only the twenty settled lines are included.');
        Assert.areEqual(86.00, statement.detailPayable, 'Each line rounds using the existing payout calculator.');
        Assert.areEqual(215.00, statement.detailNet, 'Carrier amounts are separate from agent shares.');
        Assert.isFalse(statement.getDetailMismatch(), 'Unchanged detail reconciles to the recorded totals.');
        Assert.isFalse(statement.getHasDifference(), 'The seeded payment equals its calculated payable.');
        Assert.isFalse(statement.details[0].client.contains('<a'), 'Customer names contain no hyperlink markup.');
        Assert.areEqual(64, statement.fingerprint.length(), 'Source data is represented by a digest.');
    }

    /** @description Saves one File, reuses it for duplicate requests, and preserves earlier versions on change. */
    @isTest
    static void savesVersionsAndReusesIdenticalRequests() {
        Id id = payoutId();
        Test.startTest();
        AgentPayoutPdfService.FileState first = AgentPayoutPdfService.generate(new Set<Id>{ id });
        AgentPayoutPdfService.FileState duplicate = AgentPayoutPdfService.generate(new Set<Id>{ id });
        Assert.areEqual(first.versionId, duplicate.versionId, 'Repeated clicks reuse the same saved source.');
        Assert.isFalse(duplicate.stale, 'Saving does not make its own source fingerprint stale.');
        update new Agent_Payout__c(Id = id, Amount_Paid__c = 90);
        Assert.isTrue(AgentPayoutPdfService.readStates(new Set<Id>{ id }).get(id).stale, 'An edited payment needs regeneration.');
        AgentPayoutPdfService.FileState second = AgentPayoutPdfService.generate(new Set<Id>{ id });
        Map<Id, String> preview = AgentPayoutPdfService.readPreview(new Set<Id>{ id }, second.versionId);
        Test.stopTest();
        Assert.areEqual(first.documentId, second.documentId, 'Reissue adds a version to the same dedicated File.');
        Assert.areNotEqual(first.versionId, second.versionId, 'The new statement has a new version.');
        Assert.areEqual('2', second.versionNumber, 'Two successful source states produce two versions.');
        Assert.areEqual(2, [SELECT COUNT() FROM ContentVersion WHERE ContentDocumentId = :first.documentId], 'Prior versions remain available.');
        Assert.isNotNull(preview.get(id), 'Inline preview reads the stored bytes.');
        Assert.isTrue(second.inlineAvailable, 'Small documents can be embedded.');
        Assert.areEqual(20, [SELECT COUNT() FROM Commission_Line__c WHERE Payout__c = :id], 'Generating a PDF does not change settlement links.');
    }

    /** @description Shows differences instead of silently presenting current rates as historical payments. */
    @isTest
    static void retainsPayoutTotalsWhenRatesChange() {
        Id id = payoutId();
        Insurance__c policy = [SELECT Id FROM Insurance__c LIMIT 1];
        update new Insurance__c(Id = policy.Id, Commission_Rate__c = 80);
        Test.startTest();
        AgentPayoutPdfService.Statement statement = AgentPayoutPdfService.readStatements(new Set<Id>{ id }).get(id);
        Test.stopTest();
        Assert.areEqual(172.00, statement.detailPayable, 'Current detail uses its current source rate.');
        Assert.areEqual(86.00, statement.payout.Payable_Amount__c, 'The recorded payment calculation is never overwritten.');
        Assert.isTrue(statement.getDetailMismatch(), 'Rate changes are explicitly identified.');
    }

    /** @description Preserves negative amounts and reports missing rates as unknown rather than zero. */
    @isTest
    static void preservesChargebacksAndUnratedDetails() {
        Id id = payoutId();
        List<Commission_Line__c> lines = [SELECT Id FROM Commission_Line__c WHERE Payout__c = :id];
        for (Commission_Line__c line : lines) { line.Commission_Amount__c = -10; }
        update lines;
        update new Insurance__c(Id = [SELECT Id FROM Insurance__c LIMIT 1].Id, Commission_Rate__c = null);
        Test.startTest();
        AgentPayoutPdfService.Statement statement = AgentPayoutPdfService.readStatements(new Set<Id>{ id }).get(id);
        Test.stopTest();
        Assert.areEqual(-200, statement.detailNet, 'Negative carrier amounts are preserved.');
        Assert.areEqual(20, statement.unratedCount, 'All missing rates remain visible.');
        Assert.isNull(statement.details[0].payable, 'An unknown share is not shown as zero.');
        Assert.isTrue(statement.details[0].getUnrated(), 'The PDF can show a Not rated label.');
    }

    /** @description Keeps saved files accessible as history after a payout is voided. */
    @isTest
    static void keepsTheFileWhenPayoutIsVoided() {
        Id id = payoutId();
        Test.startTest();
        AgentPayoutPdfService.FileState saved = AgentPayoutPdfService.generate(new Set<Id>{ id });
        new AgentPayoutService().voidPayout(id, 'Synthetic cancellation');
        AgentPayoutPdfService.FileState state = AgentPayoutPdfService.readStates(new Set<Id>{ id }).get(id);
        try { AgentPayoutPdfService.generate(new Set<Id>{ id }); Assert.fail('Voided payouts cannot issue an active statement.'); }
        catch (AgentPayoutPdfService.StatementException ex) { Assert.areEqual(Label.PayoutPdf_Voided, ex.getMessage(), 'The cancellation is explained.'); }
        Test.stopTest();
        Assert.areEqual(saved.documentId, state.documentId, 'The archived statement is preserved.');
        Assert.isTrue(state.voided, 'The preview shows the current VOIDED banner.');
        Assert.isFalse(state.canGenerate, 'Regeneration is unavailable for cancelled payments.');
    }

    /** @description Rejects a substituted document pointer unless its File belongs to this payout. */
    @isTest
    static void neverFollowsAnUnlinkedFilePointer() {
        Id id = payoutId();
        ContentVersion unrelated = new ContentVersion(Title = 'Unrelated', PathOnClient = 'unrelated.pdf', VersionData = Blob.valueOf('private'));
        insert unrelated;
        unrelated = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :unrelated.Id];
        update new Agent_Payout__c(Id = id, Statement_File_Id__c = unrelated.ContentDocumentId);
        Test.startTest();
        AgentPayoutPdfService.FileState state = AgentPayoutPdfService.readStates(new Set<Id>{ id }).get(id);
        Map<Id, String> preview = AgentPayoutPdfService.readPreview(new Set<Id>{ id }, null);
        Test.stopTest();
        Assert.isNull(state.documentId, 'A pointer alone cannot grant access to a File.');
        Assert.isTrue(preview.isEmpty(), 'No unrelated File bytes are returned.');
    }

    /** @description Enforces object permissions for non-administrator users. */
    @isTest
    static void deniesAnUngrantedUser() {
        Id id = payoutId();
        User restricted = AgentPayoutTestData.createRestrictedUser('pdfdeny');
        Test.startTest();
        System.runAs(restricted) {
            try { AgentPayoutPdfService.readStates(new Set<Id>{ id }); Assert.fail('Reading payout data requires access.'); }
            catch (QueryException ex) { Assert.isNotNull(ex.getMessage(), 'User-mode queries reject inaccessible fields or objects.'); }
        }
        Test.stopTest();
    }

    /** @description Refuses an empty or multiple-record interactive rendering request. */
    @isTest
    static void rejectsEmptyGeneration() {
        Test.startTest();
        try { AgentPayoutPdfService.generate(new Set<Id>()); Assert.fail('An interactive render needs one payout.'); }
        catch (AgentPayoutPdfService.StatementException ex) { Assert.areEqual(Label.PayoutPdf_NoAccess, ex.getMessage(), 'The invalid request is controlled.'); }
        Test.stopTest();
    }
}
