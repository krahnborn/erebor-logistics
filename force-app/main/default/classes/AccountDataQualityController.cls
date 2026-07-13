public with sharing class AccountDataQualityController {
    private static final String OBJECT_API_NAME = 'Account';
    private static final String CRITICAL = 'Critical';

    @AuraEnabled(cacheable=true)
    public static ScoreSummary getScore(Id recordId) {
        if (recordId == null || recordId.getSObjectType() != Account.SObjectType) {
            throw new AuraHandledException('A valid Account record is required.');
        }

        List<Data_Quality_Rule__c> rules = [
            SELECT Name, Object_API_Name__c, Field_API_Name__c, Importance__c, Weight__c, Sort_Order__c
            FROM Data_Quality_Rule__c
            WHERE Active__c = true
            AND Object_API_Name__c = :OBJECT_API_NAME
            ORDER BY Sort_Order__c ASC NULLS LAST, Field_API_Name__c ASC
        ];

        Map<String, Schema.SObjectField> accountFields = Schema.SObjectType.Account.fields.getMap();
        Set<String> fieldNames = new Set<String>();
        for (Data_Quality_Rule__c rule : rules) {
            if (String.isNotBlank(rule.Field_API_Name__c) && accountFields.containsKey(rule.Field_API_Name__c)) {
                fieldNames.add(rule.Field_API_Name__c);
            }
        }

        Account accountRecord = queryAccount(recordId, fieldNames);
        ScoreSummary summary = new ScoreSummary();
        summary.items = new List<ScoreItem>();

        Decimal earnedWeight = 0;
        Decimal totalWeight = 0;
        Integer completeCount = 0;
        Integer missingCount = 0;
        Integer missingCriticalCount = 0;

        for (Data_Quality_Rule__c rule : rules) {
            ScoreItem item = buildItem(rule, accountFields, accountRecord);
            summary.items.add(item);

            if (!item.configured) {
                continue;
            }

            totalWeight += item.weight;
            if (item.complete) {
                earnedWeight += item.weight;
                completeCount++;
            } else {
                missingCount++;
                if (item.critical) {
                    missingCriticalCount++;
                }
            }
        }

        summary.totalRules = completeCount + missingCount;
        summary.completeRules = completeCount;
        summary.missingRules = missingCount;
        summary.missingCriticalRules = missingCriticalCount;
        summary.score = totalWeight == 0 ? 0 : Integer.valueOf((earnedWeight * 100 / totalWeight).setScale(0, RoundingMode.HALF_UP));
        summary.status = getStatus(summary.score, missingCriticalCount);
        summary.statusVariant = getStatusVariant(summary.status);
        summary.hasRules = summary.totalRules > 0;
        return summary;
    }

    private static Account queryAccount(Id recordId, Set<String> fieldNames) {
        List<String> selectFields = new List<String>{ 'Id' };
        selectFields.addAll(new List<String>(fieldNames));
        selectFields.sort();
        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM Account WHERE Id = :recordId LIMIT 1';
        List<Account> accounts = Database.query(soql);
        return accounts.isEmpty() ? null : accounts[0];
    }

    private static ScoreItem buildItem(
        Data_Quality_Rule__c rule,
        Map<String, Schema.SObjectField> accountFields,
        Account accountRecord
    ) {
        ScoreItem item = new ScoreItem();
        item.ruleName = rule.Name;
        item.objectApiName = rule.Object_API_Name__c;
        item.fieldApiName = rule.Field_API_Name__c;
        item.importance = rule.Importance__c;
        item.critical = rule.Importance__c == CRITICAL;
        item.weight = rule.Weight__c == null || rule.Weight__c <= 0 ? 1 : rule.Weight__c;
        item.configured = String.isNotBlank(item.fieldApiName) && accountFields.containsKey(item.fieldApiName);

        if (!item.configured) {
            item.fieldLabel = item.fieldApiName;
            item.complete = false;
            item.message = 'Field is not available on Account.';
            return item;
        }

        Schema.DescribeFieldResult describeField = accountFields.get(item.fieldApiName).getDescribe();
        item.fieldLabel = describeField.getLabel();

        if (!describeField.isAccessible()) {
            item.complete = false;
            item.message = 'No field access.';
            return item;
        }

        Object fieldValue = accountRecord == null ? null : accountRecord.get(item.fieldApiName);
        item.complete = isComplete(fieldValue);
        item.message = item.complete ? 'Complete' : 'Missing';
        return item;
    }

    private static Boolean isComplete(Object fieldValue) {
        if (fieldValue == null) {
            return false;
        }
        if (fieldValue instanceof String) {
            return String.isNotBlank((String) fieldValue);
        }
        return true;
    }

    private static String getStatus(Integer score, Integer missingCriticalCount) {
        if (missingCriticalCount > 0 || score < 60) {
            return 'Red';
        }
        if (score < 85) {
            return 'Amber';
        }
        return 'Green';
    }

    private static String getStatusVariant(String status) {
        if (status == 'Green') {
            return 'success';
        }
        if (status == 'Amber') {
            return 'warning';
        }
        return 'error';
    }

    public class ScoreSummary {
        @AuraEnabled public Integer score { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusVariant { get; set; }
        @AuraEnabled public Boolean hasRules { get; set; }
        @AuraEnabled public Integer totalRules { get; set; }
        @AuraEnabled public Integer completeRules { get; set; }
        @AuraEnabled public Integer missingRules { get; set; }
        @AuraEnabled public Integer missingCriticalRules { get; set; }
        @AuraEnabled public List<ScoreItem> items { get; set; }
    }

    public class ScoreItem {
        @AuraEnabled public String ruleName { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String fieldApiName { get; set; }
        @AuraEnabled public String fieldLabel { get; set; }
        @AuraEnabled public String importance { get; set; }
        @AuraEnabled public Decimal weight { get; set; }
        @AuraEnabled public Boolean critical { get; set; }
        @AuraEnabled public Boolean configured { get; set; }
        @AuraEnabled public Boolean complete { get; set; }
        @AuraEnabled public String message { get; set; }
    }
}
