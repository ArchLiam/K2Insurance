/**
 * @description Reads payout statements and preserves generated PDFs as versions of a dedicated File.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
public inherited sharing class AgentPayoutPdfService {
    private static final Integer MAX_LINES = 5000;
    private static final Integer MAX_PREVIEW_BYTES = 1500000;
    @TestVisible private static Blob renderedPdf;

    /**
     * @description Represents a controlled statement generation failure.
     * @author Liam Jeong <liam.jeong@5sinfusion.com>
     */
    public class StatementException extends Exception {}

    /**
     * @description Holds escaped plain-text detail values and the current calculated agent share.
     * @author Liam Jeong <liam.jeong@5sinfusion.com>
     */
    public class Detail {
        public String period { get; set; }
        public String client { get; set; }
        public String company { get; set; }
        public String policy { get; set; }
        public String carrier { get; set; }
        public Decimal commission { get; set; }
        public Decimal rate { get; set; }
        public Decimal payable { get; set; }
        /** @description Identifies an unknown share. @return Whether the source rate is absent. */
        public Boolean getUnrated() { return rate == null; }
    }

    /**
     * @description Combines the saved payout totals with its currently linked commission details.
     * @author Liam Jeong <liam.jeong@5sinfusion.com>
     */
    public class Statement {
        public Agent_Payout__c payout { get; set; }
        public List<Detail> details { get; set; }
        public Decimal detailPayable { get; set; }
        public Decimal detailNet { get; set; }
        public Integer unratedCount { get; set; }
        public String fingerprint { get; set; }
        public Datetime generatedAt { get; set; }
        /** @description Identifies cancelled statements. @return Whether the payout is voided. */
        public Boolean getVoided() { return payout.Status__c == 'Voided'; }
        /** @description Keeps actual cash separate from the saved calculation. @return The recorded difference. */
        public Decimal getDifference() { return money(payout.Amount_Paid__c) - money(payout.Payable_Amount__c); }
        /** @description Controls the reconciliation row. @return Whether actual and calculated amounts differ. */
        public Boolean getHasDifference() { return getDifference() != 0; }
        /** @description Compares current detail with recorded totals. @return Whether reconciliation is needed. */
        public Boolean getDetailMismatch() {
            return payout.Line_Count__c != details.size()
                || money(payout.Payable_Amount__c) != detailPayable
                || money(payout.Lines_Net_Amount__c) != detailNet
                || payout.Unrated_Line_Count__c != unratedCount;
        }
    }

    /**
     * @description Describes the latest saved File and whether the source has changed since generation.
     * @author Liam Jeong <liam.jeong@5sinfusion.com>
     */
    public class FileState {
        @AuraEnabled public Id documentId;
        @AuraEnabled public Id versionId;
        @AuraEnabled public String versionNumber;
        @AuraEnabled public Datetime generatedAt;
        @AuraEnabled public Boolean stale;
        @AuraEnabled public Boolean voided;
        @AuraEnabled public Boolean detailMismatch;
        @AuraEnabled public Boolean canGenerate;
        @AuraEnabled public Boolean inlineAvailable;
    }

    /**
     * @description Reads complete statements with user permissions and a bounded collection query.
     * @param payoutIds The payouts to read.
     * @return Statements keyed by payout id.
     */
    public static Map<Id, Statement> readStatements(Set<Id> payoutIds) {
        Map<Id, Statement> statements = new Map<Id, Statement>();
        Map<Id, List<String>> signatures = new Map<Id, List<String>>();
        for (Agent_Payout__c payout : [
            SELECT Id, Name, Agent__c, Agent__r.Name, Period_Start__c, Period_End__c,
                   Paid_Date__c, Status__c, Payment_Method__c, Reference_Number__c,
                   Amount_Paid__c, Payable_Amount__c, Lines_Net_Amount__c,
                   Chargeback_Amount__c, Line_Count__c, Unrated_Line_Count__c, Unrated_Net_Amount__c,
                   Statement_File_Id__c, Statement_Source_Hash__c, Statement_Generated_At__c
            FROM Agent_Payout__c WHERE Id IN :payoutIds WITH USER_MODE
        ]) {
            Statement statement = new Statement();
            statement.payout = payout;
            statement.details = new List<Detail>();
            statement.detailPayable = 0;
            statement.detailNet = 0;
            statement.unratedCount = 0;
            statement.generatedAt = System.now();
            statements.put(payout.Id, statement);
            // A fixed-order value list is stable across the calling and Visualforce transactions.
            List<Object> header = new List<Object>{
                payout.Id, payout.Name, payout.Agent__c, payout.Agent__r.Name,
                payout.Period_Start__c, payout.Period_End__c, payout.Paid_Date__c,
                payout.Status__c, payout.Payment_Method__c, payout.Reference_Number__c,
                payout.Amount_Paid__c, payout.Payable_Amount__c, payout.Lines_Net_Amount__c,
                payout.Chargeback_Amount__c, payout.Line_Count__c,
                payout.Unrated_Line_Count__c, payout.Unrated_Net_Amount__c
            };
            signatures.put(payout.Id, new List<String>{ digest(JSON.serialize(header)) });
        }
        Integer cap = MAX_LINES + 1;
        for (Commission_Line__c line : [
            SELECT Id, Payout__c, Commission_Amount__c, Commission_Date__c,
                   Commission_Statement__r.Payment_Period__c,
                   Commission_Statement__r.Insurance_Provider__r.Name,
                   Policy_Number__r.Policy_Number__c, Policy_Number_Imported__c,
                   Policy_Number__r.Commission_Rate__c,
                   Policy_Number__r.Policy_Holder__r.Name, Policy_Number__r.Company__r.Name
            FROM Commission_Line__c WHERE Payout__c IN :payoutIds WITH USER_MODE
            ORDER BY Commission_Statement__r.Payment_Period__c, Policy_Number__r.Policy_Holder__r.Name, Id
            LIMIT :cap
        ]) {
            Statement statement = statements.get(line.Payout__c);
            if (statement == null) { continue; }
            Detail detail = new Detail();
            detail.period = line.Commission_Statement__r.Payment_Period__c;
            detail.carrier = line.Commission_Statement__r.Insurance_Provider__r == null
                ? null : line.Commission_Statement__r.Insurance_Provider__r.Name;
            Insurance__c policy = line.Policy_Number__r;
            detail.client = policy == null || policy.Policy_Holder__r == null ? null : policy.Policy_Holder__r.Name;
            detail.company = policy == null || policy.Company__r == null ? null : policy.Company__r.Name;
            detail.policy = policy == null ? line.Policy_Number_Imported__c : policy.Policy_Number__c;
            detail.rate = policy == null ? null : policy.Commission_Rate__c;
            detail.commission = money(line.Commission_Amount__c);
            detail.payable = AgentPayoutCalculator.computePayable(detail.commission, detail.rate);
            statement.detailPayable += money(detail.payable);
            statement.detailNet += detail.commission;
            if (detail.rate == null) { statement.unratedCount++; }
            statement.details.add(detail);
            signatures.get(line.Payout__c).add(digest(JSON.serialize(new List<Object>{
                line.Id, detail.period, detail.client, detail.company, detail.policy,
                detail.carrier, detail.commission, detail.rate, detail.payable
            })));
        }
        Integer totalRows = 0;
        for (Id payoutId : statements.keySet()) {
            Statement statement = statements.get(payoutId);
            totalRows += statement.details.size();
            statement.fingerprint = digest(String.join(signatures.get(payoutId), '|'));
        }
        if (totalRows > MAX_LINES) { throw new StatementException(Label.PayoutPdf_TooManyLines); }
        return statements;
    }

    /**
     * @description Returns the saved document metadata without creating or rendering any file.
     * @param payoutIds The requested payout ids.
     * @return File states keyed by payout id.
     */
    public static Map<Id, FileState> readStates(Set<Id> payoutIds) {
        Map<Id, Statement> statements = readStatements(payoutIds);
        return statesFor(statements, readVersions(statements));
    }

    /**
     * @description Saves a statement after rendering, using a locked payout to serialize competing requests.
     * @param payoutIds A collection containing exactly one payout for this interactive render.
     * @return The latest saved File state.
     */
    public static FileState generate(Set<Id> payoutIds) {
        if (payoutIds == null || payoutIds.size() != 1) { throw new StatementException(Label.PayoutPdf_NoAccess); }
        Id payoutId = new List<Id>(payoutIds)[0];
        Statement before = readStatements(payoutIds).get(payoutId);
        if (before == null || !canGenerate()) { throw new StatementException(Label.PayoutPdf_NoAccess); }
        if (before.getVoided()) { throw new StatementException(Label.PayoutPdf_Voided); }
        if (before.details.isEmpty()) { throw new StatementException(Label.PayoutPdf_NoLines); }
        Map<Id, Statement> initial = new Map<Id, Statement>{ payoutId => before };
        Map<Id, ContentVersion> versions = readVersions(initial);
        ContentVersion existing = versions.get(payoutId);
        if (isCurrent(before, existing)) { return statesFor(initial, versions).get(payoutId); }

        Blob pdf;
        if (Test.isRunningTest()) {
            pdf = renderedPdf == null ? Blob.valueOf('%PDF-1.4 test statement') : renderedPdf;
        } else {
            PageReference page = Page.K2AgentPayoutPdf;
            page.getParameters().put('id', payoutId);
            page.getParameters().put('source', before.fingerprint);
            pdf = page.getContentAsPDF();
        }
        // Rendering happens before DML; the Visualforce request must see committed payout data.
        List<Agent_Payout__c> locks = [SELECT Id FROM Agent_Payout__c WHERE Id IN :payoutIds WITH USER_MODE FOR UPDATE];
        Statement after = readStatements(payoutIds).get(payoutId);
        if (after == null || before.fingerprint != after.fingerprint) {
            throw new StatementException(Label.PayoutPdf_SourceChanged);
        }
        Map<Id, Statement> current = new Map<Id, Statement>{ payoutId => after };
        versions = readVersions(current);
        existing = versions.get(payoutId);
        if (isCurrent(after, existing)) { return statesFor(current, versions).get(payoutId); }
        String title = 'K2_Payout_' + after.payout.Name;
        ContentVersion version = new ContentVersion(
            Title = title, PathOnClient = title + '.pdf', VersionData = pdf,
            Description = marker(payoutId, after.fingerprint)
        );
        if (existing == null) { version.FirstPublishLocationId = payoutId; }
        else { version.ContentDocumentId = existing.ContentDocumentId; }
        Savepoint restorePoint = Database.setSavepoint();
        try {
            Database.insert(new List<ContentVersion>{ version }, AccessLevel.USER_MODE);
            Set<Id> versionIds = new Set<Id>{ version.Id };
            ContentVersion saved = [SELECT Id, ContentDocumentId, VersionNumber, CreatedDate, ContentSize, Description
                                    FROM ContentVersion WHERE Id IN :versionIds WITH USER_MODE][0];
            Agent_Payout__c stamp = new Agent_Payout__c(
                Id = payoutId, Statement_File_Id__c = saved.ContentDocumentId,
                Statement_Source_Hash__c = after.fingerprint, Statement_Generated_At__c = saved.CreatedDate
            );
            Database.update(new List<Agent_Payout__c>{ stamp }, AccessLevel.USER_MODE);
            after.payout.Statement_Source_Hash__c = after.fingerprint;
            return statesFor(current, new Map<Id, ContentVersion>{ payoutId => saved }).get(payoutId);
        } catch (Exception ex) {
            Database.rollback(restorePoint);
            throw ex;
        }
    }

    /**
     * @description Reads only the explicitly linked statement version for an inline browser preview.
     * @param payoutIds The requested payouts.
     * @param requestedVersionId The exact saved version displayed by the client.
     * @return Base64 PDF data keyed by payout id; large documents use the standard Files preview.
     */
    public static Map<Id, String> readPreview(Set<Id> payoutIds, Id requestedVersionId) {
        Map<Id, Statement> statements = readStatements(payoutIds);
        Map<Id, ContentVersion> versions = readVersions(statements);
        Map<Id, Id> payoutsByVersion = new Map<Id, Id>();
        for (Id payoutId : versions.keySet()) {
            ContentVersion version = versions.get(payoutId);
            if (version.Id == requestedVersionId && version.ContentSize <= MAX_PREVIEW_BYTES) {
                payoutsByVersion.put(version.Id, payoutId);
            }
        }
        Map<Id, String> content = new Map<Id, String>();
        Set<Id> versionIds = payoutsByVersion.keySet();
        for (ContentVersion version : [SELECT Id, VersionData FROM ContentVersion WHERE Id IN :versionIds WITH USER_MODE]) {
            content.put(payoutsByVersion.get(version.Id), EncodingUtil.base64Encode(version.VersionData));
        }
        return content;
    }

    /**
     * @description Resolves document pointers only when the File is actually linked to the same payout.
     * @param statements The accessible statements.
     * @return The latest PDF versions keyed by payout.
     */
    private static Map<Id, ContentVersion> readVersions(Map<Id, Statement> statements) {
        Set<Id> payoutIds = statements.keySet();
        Set<Id> documentIds = new Set<Id>();
        Map<Id, Id> payoutByDocument = new Map<Id, Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink
            WHERE LinkedEntityId IN :payoutIds WITH USER_MODE
        ]) {
            if (String.valueOf(link.ContentDocumentId) == statements.get(link.LinkedEntityId).payout.Statement_File_Id__c) {
                documentIds.add(link.ContentDocumentId);
                payoutByDocument.put(link.ContentDocumentId, link.LinkedEntityId);
            }
        }
        Map<Id, ContentVersion> versions = new Map<Id, ContentVersion>();
        for (ContentVersion version : [
            SELECT Id, ContentDocumentId, VersionNumber, CreatedDate, ContentSize, Description
            FROM ContentVersion WHERE ContentDocumentId IN :documentIds AND IsLatest = true AND FileType = 'PDF'
            WITH USER_MODE
        ]) {
            Id payoutId = payoutByDocument.get(version.ContentDocumentId);
            if (version.Description != null && version.Description.startsWith('K2-PAYOUT:' + payoutId + ':')) {
                versions.put(payoutId, version);
            }
        }
        return versions;
    }

    /**
     * @description Shapes accessible metadata for the sidebar without exposing source records.
     * @param statements The source statements.
     * @param versions The saved document versions.
     * @return Sidebar states keyed by payout.
     */
    private static Map<Id, FileState> statesFor(Map<Id, Statement> statements, Map<Id, ContentVersion> versions) {
        Map<Id, FileState> states = new Map<Id, FileState>();
        for (Id payoutId : statements.keySet()) {
            Statement statement = statements.get(payoutId);
            ContentVersion version = versions.get(payoutId);
            FileState state = new FileState();
            state.voided = statement.getVoided();
            state.detailMismatch = statement.getDetailMismatch();
            state.canGenerate = canGenerate() && !state.voided && !statement.details.isEmpty();
            state.stale = version != null && !isCurrent(statement, version);
            state.inlineAvailable = version != null && version.ContentSize <= MAX_PREVIEW_BYTES;
            if (version != null) {
                state.documentId = version.ContentDocumentId;
                state.versionId = version.Id;
                state.versionNumber = version.VersionNumber;
                state.generatedAt = version.CreatedDate;
            }
            states.put(payoutId, state);
        }
        return states;
    }

    /**
     * @description Checks both the saved source marker and the payout's generation fingerprint.
     * @param statement The current statement.
     * @param version The saved version, if one exists.
     * @return Whether the existing version already represents this source.
     */
    private static Boolean isCurrent(Statement statement, ContentVersion version) {
        return version != null && statement.payout.Statement_Source_Hash__c == statement.fingerprint
            && version.Description == marker(statement.payout.Id, statement.fingerprint);
    }

    /**
     * @description Checks the field and object permissions needed to save and associate a File.
     * @return Whether generation is offered to the current user.
     */
    private static Boolean canGenerate() {
        return Agent_Payout__c.SObjectType.getDescribe().isUpdateable()
            && Agent_Payout__c.Statement_File_Id__c.getDescribe().isUpdateable()
            && Agent_Payout__c.Statement_Source_Hash__c.getDescribe().isUpdateable()
            && Agent_Payout__c.Statement_Generated_At__c.getDescribe().isUpdateable()
            && ContentVersion.SObjectType.getDescribe().isCreateable();
    }

    /**
     * @description Identifies a generated statement without relying on a user-editable filename.
     * @param payoutId The owning payout.
     * @param fingerprint The source fingerprint.
     * @return The file provenance marker.
     */
    private static String marker(Id payoutId, String fingerprint) { return 'K2-PAYOUT:' + payoutId + ':' + fingerprint; }

    /**
     * @description Hashes the ordered source without retaining customer values in file metadata.
     * @param value The value to hash.
     * @return A SHA-256 hexadecimal digest.
     */
    private static String digest(String value) { return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(value))); }

    /**
     * @description Treats absent totals as zero for reconciliation without assigning unknown rates.
     * @param amount The amount.
     * @return The amount or zero.
     */
    private static Decimal money(Decimal amount) { return amount == null ? 0 : amount; }
}
