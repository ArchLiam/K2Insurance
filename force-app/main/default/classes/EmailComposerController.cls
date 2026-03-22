/**
 * @description Server-side controller for the Email Composer LWC.
 * Supports Contact and Lead record pages. Provides email templates,
 * org-wide sender addresses, native merge field resolution, and email sending.
 * @author Liam Jeong (liam.jeong@5sinfusion.com)
 * @date 2026-03-16
 */
public with sharing class EmailComposerController {

    /**
     * @description DTO for an email template option in the template dropdown.
     */
    public class TemplateOption {
        @AuraEnabled public Id templateId;
        @AuraEnabled public String label;

        public TemplateOption(Id templateId, String label) {
            this.templateId = templateId;
            this.label = label;
        }
    }

    /**
     * @description DTO for a sender option in the Send From dropdown.
     */
    public class SenderOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;

        public SenderOption(Id id, String label) {
            this.id = id;
            this.label = label;
        }
    }

    /**
     * @description Response DTO for getTemplateContent: resolved subject and body.
     */
    public class TemplateContent {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String templateName;
        @AuraEnabled public String subject;
        @AuraEnabled public String htmlBody;
        @AuraEnabled public String plainTextBody;
    }

    /**
     * @description Returns all verified Org-Wide Email Addresses available as senders.
     * @return List of SenderOption DTOs
     */
    @AuraEnabled(cacheable=true)
    public static List<SenderOption> getOrgWideEmailAddresses() {
        List<SenderOption> options = new List<SenderOption>();
        for (OrgWideEmailAddress owa : [
            SELECT Id, DisplayName, Address
            FROM OrgWideEmailAddress
            ORDER BY DisplayName
        ]) {
            options.add(new SenderOption(
                owa.Id,
                owa.DisplayName + ' <' + owa.Address + '>'
            ));
        }
        return options;
    }

    /**
     * @description Returns all active email templates ordered by name.
     * @return List of TemplateOption DTOs
     */
    @AuraEnabled(cacheable=true)
    public static List<TemplateOption> getEmailTemplates() {
        List<TemplateOption> options = new List<TemplateOption>();
        for (EmailTemplate t : [
            SELECT Id, Name
            FROM EmailTemplate
            WHERE IsActive = true
            ORDER BY Name
        ]) {
            options.add(new TemplateOption(
                t.Id,
                String.isBlank(t.Name) ? 'Untitled Template' : t.Name
            ));
        }
        return options;
    }

    /**
     * @description Loads a template's subject and body with all merge fields resolved.
     * Uses Salesforce native rendering — works for both Contact and Lead records.
     * @param templateId  Id of the EmailTemplate to load
     * @param recordId    Id of the Contact or Lead record for merge field resolution
     * @return TemplateContent with resolved subject and body
     */
    @AuraEnabled(cacheable=true)
    public static TemplateContent getTemplateContent(Id templateId, Id recordId) {
        TemplateContent result = new TemplateContent();
        result.success = false;

        if (templateId == null) {
            result.message = 'No template selected.';
            return result;
        }

        try {
            EmailTemplate tmpl = [
                SELECT Id, Name, Subject, HtmlValue, Body
                FROM EmailTemplate
                WHERE Id = :templateId
                LIMIT 1
            ];

            result.templateName = tmpl.Name;

            // Native rendering resolves all merge field syntaxes
            // ({!Contact.Field}, {{Recipient.Field}}, etc.) for Contact and Lead.
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(
                templateId,
                recordId,   // recipientId — resolves Recipient.* fields
                recordId    // relatedToId — resolves object-specific merge fields
            );

            String renderedSubject  = rendered.getSubject();
            String renderedHtmlBody = rendered.getHtmlBody();
            String renderedTextBody = rendered.getPlainTextBody();

            // Some Lightning Email Template types return empty body from renderStoredEmailTemplate.
            // Fall back to raw HtmlValue / Body fields in that case.
            result.subject       = String.isNotBlank(renderedSubject)  ? renderedSubject  : tmpl.Subject;
            result.htmlBody      = String.isNotBlank(renderedHtmlBody) ? renderedHtmlBody : tmpl.HtmlValue;
            result.plainTextBody = String.isNotBlank(renderedTextBody) ? renderedTextBody : tmpl.Body;
            result.success       = true;

            if (String.isBlank(result.htmlBody) && String.isBlank(result.plainTextBody)) {
                result.message = 'This template has no body content.';
            }

        } catch (Exception ex) {
            result.success = false;
            result.message = 'Unable to load template: ' + ex.getMessage();
        }

        return result;
    }

    /**
     * @description Sends a single email and logs it as an Activity on the record.
     * @param recordId              Id of the Contact or Lead (targetObjectId for activity logging)
     * @param toAddress             Recipient email address
     * @param subject               Email subject
     * @param htmlBody              HTML body of the email
     * @param orgWideEmailAddressId Id of the OrgWideEmailAddress to send from (null = current user)
     * @throws AuraHandledException when toAddress or subject is blank, or on send failure
     */
    @AuraEnabled
    public static void sendEmail(Id recordId, String toAddress, String subject, String htmlBody, Id orgWideEmailAddressId) {
        if (String.isBlank(toAddress)) {
            throw new AuraHandledException('Recipient email address is required.');
        }
        if (String.isBlank(subject)) {
            throw new AuraHandledException('Subject is required.');
        }

        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ toAddress });
            email.setSubject(subject);
            email.setHtmlBody(String.isNotBlank(htmlBody) ? htmlBody : '');

            if (orgWideEmailAddressId != null) {
                email.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }

            if (recordId != null) {
                email.setTargetObjectId(recordId);
                email.setSaveAsActivity(true);
            }

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to send email: ' + ex.getMessage());
        }
    }

}
