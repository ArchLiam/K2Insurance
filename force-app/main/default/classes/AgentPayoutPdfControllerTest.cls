/**
 * @description Verifies the sidebar adapter returns stored File metadata and controlled errors.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@isTest
private class AgentPayoutPdfControllerTest {
    /** @description Exercises generation, metadata and bytes through the actual sidebar entry points. */
    @isTest
    static void generatesAndReadsSavedFile() {
        Id id = AgentPayoutPdfTestData.createPayout();
        Test.startTest();
        AgentPayoutPdfService.FileState empty = AgentPayoutPdfController.getState(id);
        AgentPayoutPdfService.FileState saved = AgentPayoutPdfController.generatePdf(id);
        String preview = AgentPayoutPdfController.getPreview(id, saved.versionId);
        Test.stopTest();
        Assert.isNull(empty.documentId, 'Reading an empty state never generates a file.');
        Assert.isNotNull(saved.versionId, 'Generation saves the file.');
        Assert.isTrue(EncodingUtil.base64Decode(preview).toString().startsWith('%PDF'), 'The preview reads stored PDF bytes.');
    }

    /** @description Converts invalid identifiers into user-facing errors without querying arbitrary objects. */
    @isTest
    static void rejectsInvalidIds() {
        AgentPayoutPdfTestData.createPayout();
        Test.startTest();
        try { AgentPayoutPdfController.getState(null); Assert.fail('A missing id is rejected.'); } catch (AuraHandledException ex) { Assert.isNotNull(ex, 'The read error is controlled.'); }
        try { AgentPayoutPdfController.getPreview(null, null); Assert.fail('A missing id is rejected.'); } catch (AuraHandledException ex) { Assert.isNotNull(ex, 'The preview error is controlled.'); }
        try { AgentPayoutPdfController.generatePdf(UserInfo.getUserId()); Assert.fail('The wrong object is rejected.'); } catch (AuraHandledException ex) { Assert.isNotNull(ex, 'The write error is controlled.'); }
        Test.stopTest();
    }
}
