/**
 * @description Test class for EmailComposerController.
 * @author Liam Jeong (liam.jeong@5sinfusion.com)
 * @date 2026-03-16
 */
@IsTest
private class EmailComposerControllerTest {

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /**
     * Inserts an EmailTemplate (setup object) inside System.runAs() FIRST,
     * before any non-setup DML, to satisfy the MIXED_DML rule.
     */
    private static EmailTemplate insertTemplate(String devName) {
        EmailTemplate tmpl = new EmailTemplate(
            Name          = 'Test Template',
            DeveloperName = devName,
            Subject       = 'Hello',
            Body          = 'Test body.',
            TemplateType  = 'text',
            IsActive      = true,
            FolderId      = UserInfo.getUserId()
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert tmpl;
        }
        return tmpl;
    }

    /** Creates a Contact with email. Must be called AFTER any setup-object DML. */
    private static Contact insertContact() {
        Account acct = new Account(Name = 'Test Account');
        insert acct;
        Contact con = new Contact(
            FirstName = 'Jane', LastName  = 'Doe',
            Email     = 'jane.doe@example.com', Phone = '555-0100',
            AccountId = acct.Id
        );
        insert con;
        return con;
    }

    /** Creates a Lead with email. Must be called AFTER any setup-object DML. */
    private static Lead insertLead() {
        Lead ld = new Lead(
            FirstName = 'John', LastName = 'Smith',
            Email     = 'john.smith@example.com', Phone = '555-0200',
            Company   = 'Test Co'
        );
        insert ld;
        return ld;
    }

    // ─── getEmailTemplates ────────────────────────────────────────────────────

    @IsTest
    static void getEmailTemplates_returnsActiveTemplates() {
        insertTemplate('EC_Active');

        Test.startTest();
        List<EmailComposerController.TemplateOption> options =
            EmailComposerController.getEmailTemplates();
        Test.stopTest();

        Assert.isTrue(options.size() > 0, 'Expected at least one active template');
        Assert.isNotNull(options[0].templateId);
    }

    @IsTest
    static void getEmailTemplates_excludesInactiveTemplates() {
        EmailTemplate inactive;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            inactive = new EmailTemplate(
                Name = 'Inactive', DeveloperName = 'EC_Inactive',
                Subject = 'Inactive', Body = 'Inactive body',
                TemplateType = 'text', IsActive = false,
                FolderId = UserInfo.getUserId()
            );
            insert inactive;
        }

        Test.startTest();
        List<EmailComposerController.TemplateOption> options =
            EmailComposerController.getEmailTemplates();
        Test.stopTest();

        for (EmailComposerController.TemplateOption opt : options) {
            Assert.areNotEqual(inactive.Id, opt.templateId,
                'Inactive template should not be returned');
        }
    }

    // ─── getOrgWideEmailAddresses ─────────────────────────────────────────────

    @IsTest
    static void getOrgWideEmailAddresses_returnsList() {
        Test.startTest();
        List<EmailComposerController.SenderOption> options =
            EmailComposerController.getOrgWideEmailAddresses();
        Test.stopTest();

        Assert.isNotNull(options, 'Expected a non-null list');
    }

    @IsTest
    static void getOrgWideEmailAddresses_labelFormat() {
        List<OrgWideEmailAddress> owas = [
            SELECT Id, DisplayName, Address FROM OrgWideEmailAddress LIMIT 1
        ];
        if (owas.isEmpty()) return;

        Test.startTest();
        List<EmailComposerController.SenderOption> options =
            EmailComposerController.getOrgWideEmailAddresses();
        Test.stopTest();

        Assert.isTrue(
            options[0].label.contains('<') && options[0].label.contains('>'),
            'Label should be in "DisplayName <address>" format'
        );
    }

    // ─── getTemplateContent ───────────────────────────────────────────────────

    @IsTest
    static void getTemplateContent_nullTemplateId_returnsFailure() {
        // Insert template first (setup), then contact (non-setup)
        insertTemplate('EC_NullId');
        Contact con = insertContact();

        Test.startTest();
        EmailComposerController.TemplateContent result =
            EmailComposerController.getTemplateContent(null, con.Id);
        Test.stopTest();

        Assert.isFalse(result.success);
        Assert.areEqual('No template selected.', result.message);
    }

    @IsTest
    static void getTemplateContent_withContact_returnsSuccess() {
        EmailTemplate tmpl = insertTemplate('EC_WithContact');
        Contact con = insertContact();

        Test.startTest();
        EmailComposerController.TemplateContent result =
            EmailComposerController.getTemplateContent(tmpl.Id, con.Id);
        Test.stopTest();

        Assert.isTrue(result.success, 'Expected success but got: ' + result.message);
        Assert.areEqual('Test Template', result.templateName);
        Assert.isNotNull(result.subject);
    }

    @IsTest
    static void getTemplateContent_withLead_returnsSuccess() {
        EmailTemplate tmpl = insertTemplate('EC_WithLead');
        Lead ld = insertLead();

        Test.startTest();
        EmailComposerController.TemplateContent result =
            EmailComposerController.getTemplateContent(tmpl.Id, ld.Id);
        Test.stopTest();

        Assert.isTrue(result.success, 'Expected success but got: ' + result.message);
        Assert.areEqual('Test Template', result.templateName);
        Assert.isNotNull(result.subject);
    }

    @IsTest
    static void getTemplateContent_invalidTemplateId_returnsFailure() {
        insertTemplate('EC_InvalidId');
        Contact con = insertContact();
        Id fakeId = '00X000000000001AAA';

        Test.startTest();
        EmailComposerController.TemplateContent result =
            EmailComposerController.getTemplateContent(fakeId, con.Id);
        Test.stopTest();

        Assert.isFalse(result.success);
        Assert.isTrue(result.message.startsWith('Unable to load template:'));
    }

    // ─── sendEmail ────────────────────────────────────────────────────────────

    @IsTest
    static void sendEmail_withContact_succeeds() {
        Contact con = insertContact();

        Test.startTest();
        EmailComposerController.sendEmail(
            con.Id, con.Email, 'Test Subject', '<p>Hello</p>', null
        );
        // Capture invocations before Test.stopTest() resets the counter
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, invocations, 'Expected one email send');
    }

    @IsTest
    static void sendEmail_withLead_succeeds() {
        Lead ld = insertLead();

        Test.startTest();
        EmailComposerController.sendEmail(
            ld.Id, ld.Email, 'Test Subject', '<p>Hello</p>', null
        );
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, invocations, 'Expected one email send');
    }

    @IsTest
    static void sendEmail_blankToAddress_throwsException() {
        Contact con = insertContact();
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            EmailComposerController.sendEmail(
                con.Id, '', 'Subject', '<p>Body</p>', null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'Expected AuraHandledException for blank toAddress');
    }

    @IsTest
    static void sendEmail_blankSubject_throwsException() {
        Contact con = insertContact();
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            EmailComposerController.sendEmail(
                con.Id, con.Email, '', '<p>Body</p>', null
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'Expected AuraHandledException for blank subject');
    }

    @IsTest
    static void sendEmail_nullRecordId_succeeds() {
        Test.startTest();
        EmailComposerController.sendEmail(
            null, 'test@example.com', 'Subject', '<p>Body</p>', null
        );
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, invocations, 'Expected one email send');
    }

    @IsTest
    static void sendEmail_nullHtmlBody_succeeds() {
        Contact con = insertContact();

        Test.startTest();
        EmailComposerController.sendEmail(
            con.Id, con.Email, 'Subject', null, null
        );
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, invocations, 'Expected one email send');
    }
}
