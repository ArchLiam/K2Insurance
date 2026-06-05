/**
 * @description Best-effort creation of a standard Note (ContentNote) from text,
 * linked to a parent record. Exposed as an Invocable Action so Flows can create
 * Notes — Flow can't base64-encode ContentNote.Content natively. Used by the
 * Lead → Contact conversion flow to carry the Lead's Important Note over as a
 * Note on the new Contact.
 * @author Liam Jeong (liam.jeong@5sinfusion.com)
 * @date 2026-06-04
 */
public with sharing class ContentNoteCreator {

    /** ContentNote.Content tops out near 128KB; keep well under to be safe. */
    @TestVisible
    private static final Integer MAX_CONTENT_CHARS = 100000;

    /** Invocable input — one Note to create against one parent record. */
    public class Request {
        @InvocableVariable(label='Parent Record Id' required=true)
        public Id parentId;

        @InvocableVariable(label='Note Title')
        public String title;

        @InvocableVariable(label='Note Body (text or HTML)')
        public String body;
    }

    /**
     * @description Creates one ContentNote per request with a non-blank body and
     * links it to the request's parent. Best-effort: never throws, so a note
     * failure can't break the caller (e.g. Lead conversion).
     * @param requests note requests supplied by Flow
     */
    @InvocableMethod(label='Create Note (ContentNote)' description='Creates a standard Note from text and links it to a record')
    public static void createNotes(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        try {
            List<ContentNote> notes = new List<ContentNote>();
            List<Id> parents = new List<Id>();
            for (Request r : requests) {
                if (r == null || r.parentId == null || String.isBlank(r.body)) {
                    continue;
                }
                notes.add(new ContentNote(
                    Title = String.isBlank(r.title) ? 'Note' : r.title.left(200),
                    Content = Blob.valueOf(toNoteContent(r.body))
                ));
                parents.add(r.parentId);
            }
            if (notes.isEmpty()) {
                return;
            }
            insert notes;

            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for (Integer i = 0; i < notes.size(); i++) {
                links.add(new ContentDocumentLink(
                    ContentDocumentId = notes[i].Id,
                    LinkedEntityId = parents[i],
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
            }
            insert links;
        } catch (Exception e) {
            // Best-effort: log and swallow so note creation can't block the flow.
            System.debug(LoggingLevel.ERROR, 'ContentNoteCreator failed: ' + e.getMessage());
        }
    }

    /**
     * @description Converts arbitrary text/HTML into the simply-formatted,
     * escaped HTML that ContentNote.Content accepts: block/line tags become line
     * breaks, remaining tags are stripped, and special characters are escaped.
     * @param raw source text (may contain rich-text HTML)
     * @return ContentNote-safe HTML string
     */
    @TestVisible
    private static String toNoteContent(String raw) {
        String text = raw
            .replaceAll('(?i)<br\\s*/?>', '\n')
            .replaceAll('(?i)</p>', '\n')
            .replaceAll('(?i)</div>', '\n')
            .replaceAll('(?i)</li>', '\n')
            .replaceAll('<[^>]+>', '');
        // Decode the handful of entities rich text commonly emits.
        text = text
            .replace('&nbsp;', ' ')
            .replace('&amp;', '&')
            .replace('&lt;', '<')
            .replace('&gt;', '>')
            .replace('&quot;', '"')
            .replace('&#39;', '\'');
        if (text.length() > MAX_CONTENT_CHARS) {
            text = text.substring(0, MAX_CONTENT_CHARS);
        }
        // Re-escape for ContentNote, then restore line breaks as <br>.
        String content = text
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('\n', '<br>');
        return String.isBlank(content) ? '&nbsp;' : content;
    }
}
