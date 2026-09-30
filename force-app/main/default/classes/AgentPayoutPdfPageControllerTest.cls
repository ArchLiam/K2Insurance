/**
 * @description Verifies the print controller loads committed source data and validates source fingerprints.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@isTest
private class AgentPayoutPdfPageControllerTest {
    /** @description Reads the complete printable statement through the Visualforce entry point. */
    @isTest
    static void loadsTheRequestedStatement() {
        Id id = AgentPayoutPdfTestData.createPayout();
        Test.setCurrentPage(Page.K2AgentPayoutPdf);
        ApexPages.currentPage().getParameters().put('id', id);
        Test.startTest();
        AgentPayoutPdfPageController controller = new AgentPayoutPdfPageController();
        Test.stopTest();
        Assert.areEqual(id, controller.statement.payout.Id, 'The page uses the requested payout.');
        Assert.areEqual(20, controller.statement.details.size(), 'Every settled line is available to render.');
    }

    /** @description Embeds only an authorized saved File version and rejects arbitrary version requests. */
    @isTest
    static void previewsOnlyTheSavedVersion() {
        Id id = AgentPayoutPdfTestData.createPayout();
        AgentPayoutPdfService.FileState saved = AgentPayoutPdfService.generate(new Set<Id>{ id });
        Test.setCurrentPage(Page.K2AgentPayoutPdfPreview);
        ApexPages.currentPage().getParameters().put('id', id);
        ApexPages.currentPage().getParameters().put('view', 'stored');
        ApexPages.currentPage().getParameters().put('version', saved.versionId);
        Test.startTest();
        AgentPayoutPdfPageController controller = new AgentPayoutPdfPageController();
        Assert.isTrue(EncodingUtil.base64Decode(controller.savedPdf).toString().startsWith('%PDF'), 'The viewer reads saved bytes.');
        Assert.isNull(controller.statement, 'Viewing a saved PDF does not generate a new statement.');
        ApexPages.currentPage().getParameters().put('version', UserInfo.getUserId());
        try { new AgentPayoutPdfPageController(); Assert.fail('Unrelated versions are rejected.'); }
        catch (AgentPayoutPdfService.StatementException ex) { Assert.areEqual(Label.PayoutPdf_LoadError, ex.getMessage(), 'An inaccessible version is controlled.'); }
        ApexPages.currentPage().getParameters().put('version', 'invalid');
        try { new AgentPayoutPdfPageController(); Assert.fail('Malformed versions are rejected.'); }
        catch (AgentPayoutPdfService.StatementException ex) { Assert.areEqual(Label.PayoutPdf_NoAccess, ex.getMessage(), 'The invalid request is controlled.'); }
        Test.stopTest();
    }

    /** @description Prevents stale data from silently rendering under a previously calculated fingerprint. */
    @isTest
    static void rejectsStaleSourcesAndInvalidIds() {
        Id id = AgentPayoutPdfTestData.createPayout();
        Test.setCurrentPage(Page.K2AgentPayoutPdf);
        ApexPages.currentPage().getParameters().put('id', id);
        ApexPages.currentPage().getParameters().put('source', 'outdated');
        Test.startTest();
        try { new AgentPayoutPdfPageController(); Assert.fail('A changed source must not render.'); }
        catch (AgentPayoutPdfService.StatementException ex) { Assert.areEqual(Label.PayoutPdf_SourceChanged, ex.getMessage(), 'The caller is told to retry.'); }
        ApexPages.currentPage().getParameters().put('id', 'not-an-id');
        try { new AgentPayoutPdfPageController(); Assert.fail('A malformed id must not render.'); }
        catch (AgentPayoutPdfService.StatementException ex) { Assert.areEqual(Label.PayoutPdf_NoAccess, ex.getMessage(), 'Malformed ids are controlled.'); }
        Test.stopTest();
    }
}
