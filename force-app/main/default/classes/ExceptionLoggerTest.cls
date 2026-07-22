/**
 * @description Tests for ExceptionLogger — verifies a caught exception is published as an
 * Exception__e event and persisted to Error_Log__c by the subscriber flow.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@IsTest
private class ExceptionLoggerTest {

    /**
     * @description Logging a caught exception creates one Error_Log__c row at High severity.
     */
    @IsTest
    static void logCreatesErrorLog() {
        Test.startTest();
        try {
            throw new IllegalArgumentException('boom');
        } catch (Exception e) {
            ExceptionLogger.log('ExceptionLoggerTest.logCreatesErrorLog', UserInfo.getUserId(), e);
        }
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Id, Severity__c, Error_Message__c
            FROM Error_Log__c
            WHERE Apex_Class__c = 'ExceptionLoggerTest.logCreatesErrorLog'
        ];
        Assert.areEqual(1, logs.size(), 'One Error_Log__c should be created from the published event.');
        Assert.areEqual('High', logs[0].Severity__c, 'Default severity should be High.');
        Assert.isTrue(logs[0].Error_Message__c.contains('boom'), 'Message should carry the exception detail.');
    }

    /**
     * @description A null exception is a no-op — no event, no Error_Log__c, no error.
     */
    @IsTest
    static void logNullExceptionIsNoOp() {
        Test.startTest();
        ExceptionLogger.log('ExceptionLoggerTest.noop', null, null);
        Test.stopTest();

        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Error_Log__c WHERE Apex_Class__c = 'ExceptionLoggerTest.noop'],
            'A null exception must not publish telemetry.'
        );
    }

    /**
     * @description An explicit severity is recorded on the persisted Error_Log__c.
     */
    @IsTest
    static void logRespectsSeverity() {
        Test.startTest();
        try {
            throw new IllegalArgumentException('warn');
        } catch (Exception e) {
            ExceptionLogger.log('ExceptionLoggerTest.sev', null, e, ExceptionLogger.Severity.CRITICAL);
        }
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Severity__c FROM Error_Log__c WHERE Apex_Class__c = 'ExceptionLoggerTest.sev'
        ];
        Assert.areEqual(1, logs.size(), 'One Error_Log__c should be created.');
        Assert.areEqual('Critical', logs[0].Severity__c, 'Explicit severity should be recorded.');
    }
}
