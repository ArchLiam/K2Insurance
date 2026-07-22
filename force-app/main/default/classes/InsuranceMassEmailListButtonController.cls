/**
 * @description Visualforce list-view button controller for the Mass Email flow. Builds a
 * comma-separated list of the selected Insurance Ids for the VF page to pass to Lightning Out.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
public with sharing class InsuranceMassEmailListButtonController {

    /**
     * @description Comma-separated Insurance__c Ids from the list-view selection.
     */
    public String selectedIdsCsv { get; private set; }

    /**
     * @description Populates selectedIdsCsv from the set controller's selected rows.
     * @param controller StandardSetController for the Insurance__c list view.
     */
    public InsuranceMassEmailListButtonController(ApexPages.StandardSetController controller) {
        List<Insurance__c> selectedRows = (List<Insurance__c>) controller.getSelected();

        List<String> selectedIds = new List<String>();
        if (selectedRows != null) {
            for (Insurance__c insuranceRecord : selectedRows) {
                selectedIds.add((String) insuranceRecord.Id);
            }
        }

        selectedIdsCsv = String.join(selectedIds, ',');
    }
}
