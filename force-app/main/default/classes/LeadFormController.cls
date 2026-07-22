/**
 * @description Controller for the Lead Form LWC — creates Leads from public form submissions and
 * serves picklist values. Declared `without sharing` intentionally so Experience Cloud guest users
 * can create Leads regardless of record-sharing context.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
public without sharing class LeadFormController {

    // Cache lead record type lookups to avoid repeated describe calls.
    private static Map<String, Id> leadRecordTypeCache = new Map<String, Id>();

    /**
     * @description Wrapper for Lead form data; provides type-safe transfer between LWC and Apex.
     */
    public class LeadFormData {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String middleName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public Date birthdate { get; set; }
        @AuraEnabled public String genderIdentity { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public List<String> interestedInsurance { get; set; }
    }

    /**
     * @description Custom exception for Lead form validation failures.
     */
    public class LeadFormException extends Exception {}

    /**
     * @description Creates a new Lead record from form data.
     * @param formDataJson JSON string containing LeadFormData.
     * @return Id of the created Lead record.
     */
    @AuraEnabled
    public static Id createLead(String formDataJson) {
        Savepoint sp = Database.setSavepoint();

        try {
            // Parse and validate form data.
            LeadFormData formData = parseFormData(formDataJson);
            validateFormData(formData);

            // Build Lead record.
            Lead newLead = buildLeadRecord(formData);

            // Insert Lead.
            Database.SaveResult result = Database.insert(newLead, false);

            if (!result.isSuccess()) {
                String errorMessage = getErrorMessage(result.getErrors());
                throw new LeadFormException(errorMessage);
            }

            return result.getId();

        } catch (LeadFormException e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        } catch (JSONException e) {
            Database.rollback(sp);
            throw new AuraHandledException(System.Label.LeadFormCapture_InvalidFormData);
        } catch (Exception e) {
            Database.rollback(sp);
            ExceptionLogger.log('LeadFormController.createLead', null, e);
            throw new AuraHandledException(System.Label.LeadFormCapture_UnexpectedError);
        }
    }

    /**
     * @description Retrieves Gender Identity picklist values.
     * @return List of picklist options with label and value.
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getGenderIdentityOptions() {
        try {
            return getPicklistOptions('Lead', 'Gender_Identity__c');
        } catch (Exception e) {
            ExceptionLogger.log('LeadFormController.getGenderIdentityOptions', null, e);
            throw new AuraHandledException(System.Label.LeadFormCapture_GenderOptionsError);
        }
    }

    /**
     * @description Retrieves Interested Insurance picklist values, excluding Auto/Home and Commercial.
     * @return List of picklist options with label and value.
     */
    @AuraEnabled
    public static List<PicklistOption> getInterestedInsuranceOptions() {
        try {
            List<PicklistOption> allOptions = getPicklistOptions('Lead', 'Interested_Insurance__c');
            List<PicklistOption> filteredOptions = new List<PicklistOption>();

            // Values to exclude from the form.
            Set<String> excludedValues = new Set<String>{ 'Auto/Home', 'Commercial' };

            for (PicklistOption option : allOptions) {
                if (!excludedValues.contains(option.value)) {
                    filteredOptions.add(option);
                }
            }

            return filteredOptions;
        } catch (Exception e) {
            ExceptionLogger.log('LeadFormController.getInterestedInsuranceOptions', null, e);
            throw new AuraHandledException(System.Label.LeadFormCapture_InsuranceOptionsError);
        }
    }

    /**
     * @description Returns the active picklist options for a field.
     * @param objectName API name of the object.
     * @param fieldName API name of the picklist field.
     * @return List of PicklistOption records.
     */
    private static List<PicklistOption> getPicklistOptions(String objectName, String fieldName) {
        List<PicklistOption> options = new List<PicklistOption>();

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            return options;
        }

        Schema.DescribeFieldResult fieldDescribe = objType.getDescribe()
            .fields.getMap().get(fieldName)?.getDescribe();

        if (fieldDescribe == null) {
            return options;
        }

        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }

        return options;
    }

    /**
     * @description Wrapper for a picklist option (label/value pair).
     */
    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        /**
         * @description Constructs a picklist option.
         * @param label Display label.
         * @param value Stored value.
         */
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * @description Parses the JSON payload into a LeadFormData object.
     * @param formDataJson JSON string.
     * @return LeadFormData object.
     */
    private static LeadFormData parseFormData(String formDataJson) {
        if (String.isBlank(formDataJson)) {
            throw new LeadFormException(System.Label.LeadFormCapture_FormDataRequired);
        }
        return (LeadFormData) JSON.deserialize(formDataJson, LeadFormData.class);
    }

    /**
     * @description Validates required form fields, throwing on the first set of failures.
     * @param formData LeadFormData to validate.
     */
    private static void validateFormData(LeadFormData formData) {
        List<String> errors = new List<String>();

        if (String.isBlank(formData.firstName)) {
            errors.add(System.Label.LeadFormCapture_FirstNameRequired);
        }

        if (String.isBlank(formData.lastName)) {
            errors.add(System.Label.LeadFormCapture_LastNameRequired);
        }

        if (String.isBlank(formData.genderIdentity)) {
            errors.add(System.Label.LeadFormCapture_GenderIdentityRequired);
        }

        if (String.isBlank(formData.street) && String.isBlank(formData.city)) {
            errors.add(System.Label.LeadFormCapture_AddressRequired);
        }

        if (String.isBlank(formData.email)) {
            errors.add(System.Label.LeadFormCapture_EmailRequired);
        } else if (!isValidEmail(formData.email)) {
            errors.add(System.Label.LeadFormCapture_EmailInvalid);
        }

        if (String.isBlank(formData.phone)) {
            errors.add(System.Label.LeadFormCapture_PhoneRequired);
        }

        if (!errors.isEmpty()) {
            throw new LeadFormException(String.join(errors, ' '));
        }
    }

    /**
     * @description Validates email format using a permissive regex.
     * @param email Email string to validate.
     * @return True when the email is well-formed.
     */
    private static Boolean isValidEmail(String email) {
        // Permissive email regex that handles modern TLDs.
        String emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        Pattern emailPattern = Pattern.compile(emailRegex);
        Matcher matcher = emailPattern.matcher(email.trim());
        return matcher.matches();
    }

    /**
     * @description Builds a Lead sObject from validated form data.
     * @param formData LeadFormData containing form values.
     * @return Lead sObject ready for insert.
     */
    private static Lead buildLeadRecord(LeadFormData formData) {
        Lead newLead = new Lead();

        // Name fields.
        newLead.FirstName = formData.firstName?.trim();
        newLead.MiddleName = formData.middleName?.trim();
        newLead.LastName = formData.lastName?.trim();

        // Date field.
        newLead.Birthdate__c = formData.birthdate;

        // Picklist field.
        newLead.Gender_Identity__c = formData.genderIdentity;

        // Address fields.
        newLead.Street = formData.street?.trim();
        newLead.City = formData.city?.trim();
        newLead.State = formData.state?.trim();
        newLead.PostalCode = formData.postalCode?.trim();
        newLead.Country = formData.country?.trim();

        // Contact fields.
        newLead.Email = formData.email?.trim();
        newLead.Phone = formData.phone?.trim();

        // Multi-select picklist (semicolon-separated).
        if (formData.interestedInsurance != null && !formData.interestedInsurance.isEmpty()) {
            newLead.Interested_Insurance__c = String.join(formData.interestedInsurance, ';');

            Id resolvedRecordTypeId = resolveLeadRecordTypeId(formData.interestedInsurance);
            if (resolvedRecordTypeId != null) {
                newLead.RecordTypeId = resolvedRecordTypeId;
            }
        }

        // Default values.
        newLead.Company = '[Not Provided]';
        newLead.Status = 'New';
        newLead.LeadSource = 'Web';

        return newLead;
    }

    /**
     * @description Concatenates messages from a list of Database errors.
     * @param errors List of Database.Error objects.
     * @return Concatenated error message string.
     */
    private static String getErrorMessage(List<Database.Error> errors) {
        List<String> errorMessages = new List<String>();
        for (Database.Error err : errors) {
            errorMessages.add(err.getMessage());
        }
        return String.join(errorMessages, ' ');
    }

    /**
     * @description Case-insensitive membership check.
     * @param values The values to search.
     * @param targetValue The value to find.
     * @return True when targetValue is present ignoring case.
     */
    private static Boolean containsValueIgnoreCase(List<String> values, String targetValue) {
        if (values == null || String.isBlank(targetValue)) {
            return false;
        }
        for (String value : values) {
            if (value != null && value.trim().equalsIgnoreCase(targetValue)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description Resolves the Lead record type from the selected interests.
     * Priority: Medicare (regulated) > Health (also covers Group Health) > Others.
     * @param interestedInsurance Selected interest values.
     * @return Record type Id, or null when none resolves.
     */
    private static Id resolveLeadRecordTypeId(List<String> interestedInsurance) {
        if (containsValueIgnoreCase(interestedInsurance, 'Medicare')) {
            return getLeadRecordTypeId('Medicare');
        }
        if (containsValueIgnoreCase(interestedInsurance, 'Health')
            || containsValueIgnoreCase(interestedInsurance, 'Group Health')) {
            return getLeadRecordTypeId('Health');
        }
        return getLeadRecordTypeId('Others');
    }

    /**
     * @description Resolves a Lead record type Id by name or developer name, with caching.
     * @param recordTypeName Record type name or developer name.
     * @return Record type Id, or null when not found.
     */
    private static Id getLeadRecordTypeId(String recordTypeName) {
        if (String.isBlank(recordTypeName)) {
            return null;
        }

        if (leadRecordTypeCache.containsKey(recordTypeName)) {
            return leadRecordTypeCache.get(recordTypeName);
        }

        Schema.DescribeSObjectResult leadDescribe = Lead.SObjectType.getDescribe();
        Map<String, Schema.RecordTypeInfo> byName = leadDescribe.getRecordTypeInfosByName();
        Map<String, Schema.RecordTypeInfo> byDeveloperName = leadDescribe.getRecordTypeInfosByDeveloperName();

        Schema.RecordTypeInfo info = null;
        if (byName != null && byName.containsKey(recordTypeName)) {
            info = byName.get(recordTypeName);
        } else if (byDeveloperName != null && byDeveloperName.containsKey(recordTypeName)) {
            info = byDeveloperName.get(recordTypeName);
        }

        Id recordTypeId = info == null ? null : info.getRecordTypeId();
        leadRecordTypeCache.put(recordTypeName, recordTypeId);
        return recordTypeId;
    }
}
