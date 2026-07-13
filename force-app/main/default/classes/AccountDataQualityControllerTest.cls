@IsTest
private class AccountDataQualityControllerTest {
    @IsTest
    static void returnsWeightedAccountQualityScore() {
        insert new List<Data_Quality_Rule__c>{
            makeRule('Phone', 'Nice-to-have', 1, 10),
            makeRule('Website', 'Nice-to-have', 1, 20),
            makeRule('Description', 'Critical', 3, 30),
            makeRule('Rating', 'Critical', 3, 40)
        };

        Account account = new Account(
            Name = 'Erebor Logistics Test',
            Phone = '555-0100',
            Website = 'https://example.com',
            Rating = 'Hot'
        );
        insert account;

        Test.startTest();
        AccountDataQualityController.ScoreSummary summary = AccountDataQualityController.getScore(account.Id);
        Test.stopTest();

        System.assertEquals(63, summary.score, 'Five of eight weighted points are complete.');
        System.assertEquals('Red', summary.status, 'Missing critical Description keeps the record red.');
        System.assertEquals(4, summary.totalRules);
        System.assertEquals(1, summary.missingCriticalRules);
        System.assertEquals(true, summary.items[0].editable, 'Updateable fields can be fixed inline.');
    }

    @IsTest
    static void ignoresRulesForMissingFields() {
        insert makeRule('Not_A_Field__c', 'Critical', 3, 10);
        Account account = new Account(Name = 'Missing Field Test');
        insert account;

        AccountDataQualityController.ScoreSummary summary = AccountDataQualityController.getScore(account.Id);

        System.assertEquals(false, summary.hasRules);
        System.assertEquals(0, summary.totalRules);
        System.assertEquals(1, summary.items.size());
        System.assertEquals(false, summary.items[0].configured);
        System.assertEquals(null, summary.items[0].editable);
    }

    private static Data_Quality_Rule__c makeRule(String fieldApiName, String importance, Integer weight, Integer sortOrder) {
        return new Data_Quality_Rule__c(
            Name = 'Account ' + fieldApiName,
            Object_API_Name__c = 'Account',
            Field_API_Name__c = fieldApiName,
            Importance__c = importance,
            Weight__c = weight,
            Sort_Order__c = sortOrder,
            Active__c = true
        );
    }
}
