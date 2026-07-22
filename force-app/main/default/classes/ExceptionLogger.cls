/**
 * @description Central error-telemetry publisher. A catch block calls a log(...) method to
 * publish an Exception__e platform event (Publish Immediately), which the Exception_Event_Logger
 * subscriber flow persists to Error_Log__c — so a failure survives a rolled-back transaction and
 * is never silently swallowed.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
public inherited sharing class ExceptionLogger {

    /**
     * @description Severity levels; the name maps to the Error_Log__c Severity picklist
     * (Low / Medium / High / Critical).
     */
    public enum Severity { LOW, MEDIUM, HIGH, CRITICAL }

    /**
     * @description Publishes telemetry for a caught exception at High severity.
     * @param source The class or class.method where the failure occurred.
     * @param contextId The record being processed when it failed (may be null).
     * @param caught The caught exception.
     */
    public static void log(String source, Id contextId, Exception caught) {
        log(source, contextId, caught, Severity.HIGH);
    }

    /**
     * @description Publishes telemetry for a caught exception at the given severity.
     * @param source The class or class.method where the failure occurred.
     * @param contextId The record being processed when it failed (may be null).
     * @param caught The caught exception.
     * @param level The severity to record.
     */
    public static void log(String source, Id contextId, Exception caught, Severity level) {
        if (caught == null) {
            return;
        }
        EventBus.publish(new Exception__e(
            Source_Flow__c = truncate(source, 80),
            Source_Step__c = truncate(caught.getTypeName(), 80),
            Context__c = truncate(source, 255),
            Error_Message__c = caught.getMessage(),
            Stack_Trace__c = caught.getStackTraceString(),
            Record_Id__c = contextId == null ? null : String.valueOf(contextId),
            Severity__c = toPicklist(level),
            User_Id__c = UserInfo.getUserId()
        ));
    }

    /**
     * @description Maps a Severity enum to its Error_Log__c picklist label (e.g. HIGH -> 'High').
     * @param level The severity.
     * @return The picklist value.
     */
    private static String toPicklist(Severity level) {
        Severity resolved = level == null ? Severity.HIGH : level;
        return resolved.name().substring(0, 1) + resolved.name().substring(1).toLowerCase();
    }

    /**
     * @description Truncates a value to a maximum length so it fits its telemetry column.
     * @param value The value.
     * @param max The maximum length.
     * @return The value, truncated if it exceeded max.
     */
    private static String truncate(String value, Integer max) {
        if (value == null) {
            return null;
        }
        return value.length() > max ? value.substring(0, max) : value;
    }
}
