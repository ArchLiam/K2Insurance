/**
 * @description Tests for ContentNoteCreator — verifies a Note is created and
 * linked to its parent, that blank/empty/null inputs are no-ops, and that
 * rich-text HTML is sanitized to ContentNote-safe content. Assertions are
 * scoped to records linked to the test's own parent because ContentNote
 * ignores test data isolation (org-wide notes are visible in tests).
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@isTest
private class ContentNoteCreatorTest {

    @isTest
    static void createsNoteAndLinksToParent() {
        Contact c = new Contact(LastName = 'Note Target');
        insert c;

        ContentNoteCreator.Request req = new ContentNoteCreator.Request();
        req.parentId = c.Id;
        req.title = 'Important Note (from Lead)';
        req.body = '<p>생명보험 가입 필요</p><p>jenny 님 소개연락</p>';

        Test.startTest();
        ContentNoteCreator.createNotes(new List<ContentNoteCreator.Request>{ req });
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, links.size(), 'A note should be linked to the contact');

        List<ContentNote> notes = [
            SELECT Id, Title FROM ContentNote WHERE Id = :links[0].ContentDocumentId
        ];
        System.assertEquals(1, notes.size(), 'The linked ContentNote should exist');
        System.assertEquals('Important Note (from Lead)', notes[0].Title, 'Title should carry over');
    }

    @isTest
    static void skipsBlankNullAndEmptyInputs() {
        Contact c = new Contact(LastName = 'No Note');
        insert c;

        ContentNoteCreator.Request blank = new ContentNoteCreator.Request();
        blank.parentId = c.Id;
        blank.body = '   ';

        Test.startTest();
        ContentNoteCreator.createNotes(new List<ContentNoteCreator.Request>{ blank });
        ContentNoteCreator.createNotes(null);
        ContentNoteCreator.createNotes(new List<ContentNoteCreator.Request>());
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id],
            'No note should be linked for blank/empty/null input'
        );
    }

    @isTest
    static void sanitizesHtmlToSafeContent() {
        String amp = ContentNoteCreator.toNoteContent('<p>A &amp; B</p>');
        System.assert(amp.contains('A &amp; B'), 'Ampersand should be re-escaped: ' + amp);
        System.assert(!amp.contains('<p>'), 'Block tags should be stripped: ' + amp);

        String lt = ContentNoteCreator.toNoteContent('price < 100');
        System.assert(lt.contains('&lt;'), 'Bare < should be escaped: ' + lt);

        System.assertEquals('&nbsp;', ContentNoteCreator.toNoteContent('&nbsp;'),
            'Whitespace-only content should fall back to a non-blank placeholder');
    }
}