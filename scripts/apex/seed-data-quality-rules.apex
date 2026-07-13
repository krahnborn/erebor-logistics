List<Data_Quality_Rule__c> desiredRules = new List<Data_Quality_Rule__c>{
    new Data_Quality_Rule__c(
        Name = 'Account Phone',
        Object_API_Name__c = 'Account',
        Field_API_Name__c = 'Phone',
        Importance__c = 'Nice-to-have',
        Weight__c = 1,
        Sort_Order__c = 10,
        Active__c = true
    ),
    new Data_Quality_Rule__c(
        Name = 'Account Website',
        Object_API_Name__c = 'Account',
        Field_API_Name__c = 'Website',
        Importance__c = 'Nice-to-have',
        Weight__c = 1,
        Sort_Order__c = 20,
        Active__c = true
    ),
    new Data_Quality_Rule__c(
        Name = 'Account Description',
        Object_API_Name__c = 'Account',
        Field_API_Name__c = 'Description',
        Importance__c = 'Critical',
        Weight__c = 3,
        Sort_Order__c = 30,
        Active__c = true
    ),
    new Data_Quality_Rule__c(
        Name = 'Account Rating',
        Object_API_Name__c = 'Account',
        Field_API_Name__c = 'Rating',
        Importance__c = 'Critical',
        Weight__c = 3,
        Sort_Order__c = 40,
        Active__c = true
    )
};

Map<String, Data_Quality_Rule__c> existingByKey = new Map<String, Data_Quality_Rule__c>();
for (Data_Quality_Rule__c rule : [
    SELECT Id, Name, Object_API_Name__c, Field_API_Name__c
    FROM Data_Quality_Rule__c
    WHERE Object_API_Name__c = 'Account'
    AND Field_API_Name__c IN ('Phone', 'Website', 'Description', 'Rating')
]) {
    existingByKey.put(rule.Object_API_Name__c + '.' + rule.Field_API_Name__c, rule);
}

for (Data_Quality_Rule__c desiredRule : desiredRules) {
    String key = desiredRule.Object_API_Name__c + '.' + desiredRule.Field_API_Name__c;
    if (existingByKey.containsKey(key)) {
        desiredRule.Id = existingByKey.get(key).Id;
    }
}

upsert desiredRules;
