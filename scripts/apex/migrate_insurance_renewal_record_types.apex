// One-time migration: move existing Renewal Opportunities from the legacy
// Insurance_Renewal record type to the 7 new Opportunity record types that
// mirror Insurance__c (Auto_Home_Insurance, Commercial, Group_Health,
// Health_Insurance, Life_Insurance, Medicare, Other).
//
// Run with:
//   sf apex run --file scripts/apex/migrate_insurance_renewal_record_types.apex --target-org <org-alias>
//
// Re-running is a no-op once all rows are migrated (the SOQL filter excludes
// rows already on a new RT).

Set<String> newRtNames = new Set<String>{
    'Auto_Home_Insurance',
    'Commercial',
    'Group_Health',
    'Health_Insurance',
    'Life_Insurance',
    'Medicare',
    'Other'
};

Map<String, Id> nameToOppRtId = new Map<String, Id>();
for (RecordType rt : [
    SELECT Id, DeveloperName
    FROM RecordType
    WHERE SObjectType = 'Opportunity'
    AND DeveloperName IN :newRtNames
]) {
    nameToOppRtId.put(rt.DeveloperName, rt.Id);
}

System.debug('Loaded Opportunity record types: ' + nameToOppRtId.keySet());

List<Opportunity> toUpdate = new List<Opportunity>();
List<Id> skippedNoOriginal = new List<Id>();
List<String> skippedUnknownRt = new List<String>();

for (Opportunity opp : [
    SELECT Id, Original_Insurance__c, Original_Insurance__r.RecordType.DeveloperName
    FROM Opportunity
    WHERE RecordType.DeveloperName = 'Insurance_Renewal'
]) {
    if (opp.Original_Insurance__c == null) {
        skippedNoOriginal.add(opp.Id);
        continue;
    }
    String insRtName = opp.Original_Insurance__r.RecordType.DeveloperName;
    Id newRtId = nameToOppRtId.get(insRtName);
    if (newRtId == null) {
        skippedUnknownRt.add(opp.Id + ' (insurance RT: ' + insRtName + ')');
        continue;
    }
    toUpdate.add(new Opportunity(Id = opp.Id, RecordTypeId = newRtId));
}

System.debug('Renewal Opportunities to migrate: ' + toUpdate.size());
System.debug('Skipped (no Original_Insurance): ' + skippedNoOriginal);
System.debug('Skipped (unknown Insurance RT): ' + skippedUnknownRt);

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Migration complete. Updated ' + toUpdate.size() + ' Opportunities.');
} else {
    System.debug('No Opportunities to migrate.');
}
