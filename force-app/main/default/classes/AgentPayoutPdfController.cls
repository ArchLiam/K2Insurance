/**
 * @description Adapts sidebar requests to the payout PDF service with controlled user-facing errors.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
public with sharing class AgentPayoutPdfController {
    /**
     * @description Reads the latest saved statement without side effects.
     * @param payoutId The current record.
     * @return The latest File metadata.
     */
    @AuraEnabled(cacheable=true)
    public static AgentPayoutPdfService.FileState getState(Id payoutId) {
        try {
            AgentPayoutPdfService.FileState state = AgentPayoutPdfService.readStates(ids(payoutId)).get(payoutId);
            if (state == null) { throw new AgentPayoutPdfService.StatementException(Label.PayoutPdf_NoAccess); }
            return state;
        } catch (Exception ex) { throw new AuraHandledException(Label.PayoutPdf_LoadError); }
    }

    /**
     * @description Reads saved PDF bytes for the embedded preview.
     * @param payoutId The current record.
     * @param versionId The saved version identifier, which scopes the client preview cache.
     * @return The PDF encoded as base64, or null when the standard file viewer is required.
     */
    @AuraEnabled(cacheable=true)
    public static String getPreview(Id payoutId, Id versionId) {
        try { return AgentPayoutPdfService.readPreview(ids(payoutId), versionId).get(payoutId); }
        catch (Exception ex) { throw new AuraHandledException(Label.PayoutPdf_LoadError); }
    }

    /**
     * @description Generates or reuses the statement File, preserving all prior versions.
     * @param payoutId The current record.
     * @return The latest File metadata.
     */
    @AuraEnabled
    public static AgentPayoutPdfService.FileState generatePdf(Id payoutId) {
        try { return AgentPayoutPdfService.generate(ids(payoutId)); }
        catch (AgentPayoutPdfService.StatementException ex) { throw new AuraHandledException(ex.getMessage()); }
        catch (Exception ex) {
            ExceptionLogger.log('AgentPayoutPdfController.generatePdf', payoutId, ex);
            throw new AuraHandledException(Label.PayoutPdf_SaveError);
        }
    }

    /**
     * @description Validates the request identifier before any service query.
     * @param payoutId The current record.
     * @return A singleton id set.
     */
    private static Set<Id> ids(Id payoutId) {
        if (payoutId == null || payoutId.getSObjectType() != Agent_Payout__c.SObjectType) {
            throw new AgentPayoutPdfService.StatementException(Label.PayoutPdf_NoAccess);
        }
        return new Set<Id>{ payoutId };
    }
}
