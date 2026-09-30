/**
 * @description Supplies permission-checked statement data to the printable Visualforce page.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
public with sharing class AgentPayoutPdfPageController {
    public AgentPayoutPdfService.Statement statement { get; private set; }
    public String savedPdf { get; private set; }

    /**
     * @description Reads committed payout data and rejects a render when its requested source changed.
     */
    public AgentPayoutPdfPageController() {
        Id payoutId;
        try { payoutId = Id.valueOf(ApexPages.currentPage().getParameters().get('id')); }
        catch (Exception ex) { throw new AgentPayoutPdfService.StatementException(Label.PayoutPdf_NoAccess); }
        if (payoutId == null || payoutId.getSObjectType() != Agent_Payout__c.SObjectType) {
            throw new AgentPayoutPdfService.StatementException(Label.PayoutPdf_NoAccess);
        }
        if (ApexPages.currentPage().getParameters().get('view') == 'stored') {
            Id versionId;
            try { versionId = Id.valueOf(ApexPages.currentPage().getParameters().get('version')); }
            catch (Exception ex) { throw new AgentPayoutPdfService.StatementException(Label.PayoutPdf_NoAccess); }
            savedPdf = AgentPayoutPdfService.readPreview(new Set<Id>{ payoutId }, versionId).get(payoutId);
            if (savedPdf == null) { throw new AgentPayoutPdfService.StatementException(Label.PayoutPdf_LoadError); }
            return;
        }
        statement = AgentPayoutPdfService.readStatements(new Set<Id>{ payoutId }).get(payoutId);
        if (statement == null) { throw new AgentPayoutPdfService.StatementException(Label.PayoutPdf_NoAccess); }
        String expected = ApexPages.currentPage().getParameters().get('source');
        if (expected != null && expected != statement.fingerprint) {
            throw new AgentPayoutPdfService.StatementException(Label.PayoutPdf_SourceChanged);
        }
    }
}
