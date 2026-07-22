/**
 * @description Generates a K2-branded PDF from a Quote and exposes it to the quotePdfGenerator LWC
 * for preview, save (as a ContentDocument), and save-and-email actions. Also serves as the
 * Visualforce page controller for K2QuotePdf.page — pre-queries the Quote with all related fields
 * referenced by the template so the page renders without relying on StandardController cross-object
 * resolution.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
public with sharing class QuotePdfController {

    /**
     * @description The fully-loaded Quote read by K2QuotePdf.page.
     */
    public Quote q { get; private set; }

    /**
     * @description Visualforce page constructor. Reads the `id` URL parameter and loads the Quote.
     */
    public QuotePdfController() {
        String quoteId = ApexPages.currentPage().getParameters().get('id');
        if (String.isNotBlank(quoteId)) {
            q = loadQuote(quoteId);
        }
    }

    /**
     * @description Response DTO for generatePdf — base64-encoded PDF plus a suggested filename.
     */
    public class PdfResult {
        @AuraEnabled public String base64;
        @AuraEnabled public String fileName;
        @AuraEnabled public Integer sizeBytes;
    }

    /**
     * @description Response DTO for saveToQuote — Ids of the persisted ContentVersion and document.
     */
    public class SaveResult {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String fileName;
    }

    /**
     * @description Renders K2QuotePdf.page as a PDF and returns its base64 content.
     * @param quoteId Id of the Quote to render.
     * @return PdfResult with the base64 body, filename, and size.
     */
    @AuraEnabled
    public static PdfResult generatePdf(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        Blob pdf = renderPdf(quoteId);
        PdfResult result = new PdfResult();
        result.base64 = EncodingUtil.base64Encode(pdf);
        result.fileName = buildFileName(quoteId);
        result.sizeBytes = pdf.size();
        return result;
    }

    /**
     * @description Renders the PDF and saves it as a ContentVersion linked to the Quote.
     * @param quoteId Id of the Quote to render and attach the PDF to.
     * @return SaveResult with the persisted ContentVersion/ContentDocument Ids.
     */
    @AuraEnabled
    public static SaveResult saveToQuote(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        Blob pdf = renderPdf(quoteId);
        String fileName = buildFileName(quoteId);
        return persistPdf(quoteId, pdf, fileName);
    }

    /**
     * @description Renders the PDF, saves it to the Quote, then emails it as an attachment.
     * @param quoteId Id of the Quote.
     * @param toAddress Recipient email address.
     * @param subject Email subject.
     * @param htmlBody HTML body of the email.
     * @param orgWideEmailAddressId OrgWideEmailAddress Id to send from (null = current user).
     * @return SaveResult for the persisted PDF.
     */
    @AuraEnabled
    public static SaveResult saveAndEmail(
        Id quoteId,
        String toAddress,
        String subject,
        String htmlBody,
        Id orgWideEmailAddressId
    ) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (String.isBlank(toAddress)) {
            throw new AuraHandledException('Recipient email is required.');
        }
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Subject is required.');
        }

        Blob pdf = renderPdf(quoteId);
        String fileName = buildFileName(quoteId);
        SaveResult saved = persistPdf(quoteId, pdf, fileName);

        Id contactId = getContactIdForActivity(quoteId);

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(fileName);
        attachment.setBody(pdf);
        attachment.setContentType('application/pdf');

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toAddress });
        email.setSubject(subject);
        email.setHtmlBody(String.isNotBlank(htmlBody) ? htmlBody : '');
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        if (orgWideEmailAddressId != null) {
            email.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }
        if (contactId != null) {
            email.setTargetObjectId(contactId);
            email.setSaveAsActivity(true);
            email.setWhatId(quoteId);
        }

        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception ex) {
            ExceptionLogger.log('QuotePdfController.saveAndEmail', quoteId, ex);
            throw new AuraHandledException('Failed to send email. Please try again.');
        }

        return saved;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /**
     * @description Loads a Quote with every field referenced by the PDF template.
     * @param quoteId Id of the Quote.
     * @return The Quote record.
     */
    private static Quote loadQuote(Id quoteId) {
        return [
            SELECT Id, Name, QuoteNumber, Status, Description, ExpirationDate, CreatedDate,
                   BillingName, QuoteToName, Email, Phone, GrandTotal, Discount,
                   Plan_Name__c, Proposed_Premium__c, Proposed_Start_Date__c, Proposed_Term_months__c,
                   ContactId, Contact.Name,
                   Insurance_Provider__c, Insurance_Provider__r.Name,
                   OwnerId, Owner.Name, Owner.Email
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
    }

    /**
     * @description Renders the K2QuotePdf page to a PDF Blob (stubbed under test).
     * @param quoteId Id of the Quote to render.
     * @return The rendered PDF Blob.
     */
    private static Blob renderPdf(Id quoteId) {
        if (Test.isRunningTest()) {
            // getContentAsPDF() is not available in test context.
            return Blob.valueOf('TEST_PDF_CONTENT');
        }
        PageReference pdfPage = Page.K2QuotePdf;
        pdfPage.getParameters().put('id', quoteId);
        return pdfPage.getContentAsPDF();
    }

    /**
     * @description Builds the download filename from the Quote number or name.
     * @param quoteId Id of the Quote.
     * @return The PDF filename.
     */
    private static String buildFileName(Id quoteId) {
        Quote q = [SELECT QuoteNumber, Name FROM Quote WHERE Id = :quoteId LIMIT 1];
        String stem = String.isNotBlank(q.QuoteNumber) ? q.QuoteNumber : q.Name;
        return 'K2_Quote_' + stem + '.pdf';
    }

    /**
     * @description Persists the PDF as a ContentVersion linked to the Quote.
     * @param quoteId Id of the Quote to link the file to.
     * @param pdf The PDF Blob.
     * @param fileName The file name.
     * @return SaveResult with the persisted Ids.
     */
    private static SaveResult persistPdf(Id quoteId, Blob pdf, String fileName) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName.removeEnd('.pdf');
        cv.PathOnClient = fileName;
        cv.VersionData = pdf;
        cv.FirstPublishLocationId = quoteId;
        insert cv;

        ContentVersion inserted = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        SaveResult result = new SaveResult();
        result.contentVersionId = inserted.Id;
        result.contentDocumentId = inserted.ContentDocumentId;
        result.fileName = fileName;
        return result;
    }

    /**
     * @description Returns the Quote's Contact Id for activity logging.
     * @param quoteId Id of the Quote.
     * @return The Contact Id, or null when the Quote has none.
     */
    private static Id getContactIdForActivity(Id quoteId) {
        for (Quote q : [SELECT ContactId FROM Quote WHERE Id = :quoteId LIMIT 1]) {
            return q.ContactId;
        }
        return null;
    }
}
