/**
 * @description Reuses the payout test factory to prepare settled synthetic statement scenarios.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
@isTest
public with sharing class AgentPayoutPdfTestData {
    /**
     * @description Creates a settled payout with twenty commission lines and saved totals.
     * @return The created payout id.
     */
    public static Id createPayout() {
        AgentPayoutTestData.Scenario scenario = AgentPayoutTestData.build('2026-01', 20, 10.75, 40);
        AgentPayoutService service = new AgentPayoutService();
        AgentPayoutService.PayoutRequest request = new AgentPayoutService.PayoutRequest();
        request.agentId = scenario.agent.Id;
        request.periods = new List<String>{ '2026-01' };
        AgentPayoutService.PreflightDto preflight = service.getPreflight(request);
        request.expectedLineCount = preflight.lineCount;
        request.expectedLinesNetAmount = preflight.linesNetAmount;
        request.expectedPayableAmount = preflight.computedPayable;
        request.paidDate = Date.newInstance(2026, 2, 1);
        request.paymentMethod = 'Check';
        request.referenceNumber = 'TEST-STATEMENT';
        return service.createPayout(request);
    }
}
