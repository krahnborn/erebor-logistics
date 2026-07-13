public with sharing class MerchantOnboardingController {
    private static final Integer STALLED_DAYS = 3;

    public class StepSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal sortOrder;
        @AuraEnabled public String blockedReason;
        @AuraEnabled public Date completedDate;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Datetime lastActivityDate;
        @AuraEnabled public String statusClass;
    }

    public class OnboardingSummary {
        @AuraEnabled public Integer totalSteps;
        @AuraEnabled public Integer doneSteps;
        @AuraEnabled public Integer blockedSteps;
        @AuraEnabled public Integer progressPercent;
        @AuraEnabled public Boolean stalled;
        @AuraEnabled public Datetime lastActivityDate;
        @AuraEnabled public List<StepSummary> steps;
    }

    @AuraEnabled(cacheable=true)
    public static OnboardingSummary getOnboardingSummary(Id accountId) {
        validateAccountId(accountId);

        List<Onboarding_Step__c> stepRecords = [
            SELECT Id, Name, Status__c, Order__c, Blocked_Reason__c, Completed_Date__c, Owner.Name, LastModifiedDate
            FROM Onboarding_Step__c
            WHERE Account__c = :accountId
            ORDER BY Order__c ASC, CreatedDate ASC
        ];

        OnboardingSummary summary = new OnboardingSummary();
        summary.totalSteps = stepRecords.size();
        summary.doneSteps = 0;
        summary.blockedSteps = 0;
        summary.steps = new List<StepSummary>();

        for (Onboarding_Step__c stepRecord : stepRecords) {
            StepSummary step = new StepSummary();
            step.id = stepRecord.Id;
            step.name = stepRecord.Name;
            step.status = stepRecord.Status__c;
            step.sortOrder = stepRecord.Order__c;
            step.blockedReason = stepRecord.Blocked_Reason__c;
            step.completedDate = stepRecord.Completed_Date__c;
            step.ownerName = stepRecord.Owner.Name;
            step.lastActivityDate = stepRecord.LastModifiedDate;
            step.statusClass = getStatusClass(stepRecord.Status__c);
            summary.steps.add(step);

            if (stepRecord.Status__c == 'Done') {
                summary.doneSteps++;
            }
            if (stepRecord.Status__c == 'Blocked') {
                summary.blockedSteps++;
            }
            if (summary.lastActivityDate == null || stepRecord.LastModifiedDate > summary.lastActivityDate) {
                summary.lastActivityDate = stepRecord.LastModifiedDate;
            }
        }

        summary.progressPercent = calculateProgressPercent(summary.doneSteps, summary.totalSteps);
        summary.stalled = isStalled(summary.progressPercent, summary.lastActivityDate, System.now());
        return summary;
    }

    @AuraEnabled
    public static Integer createMissingStandardSteps(Id accountId) {
        validateAccountId(accountId);

        List<Standard_Onboarding_Step__mdt> standardSteps = [
            SELECT DeveloperName, Step_Label__c, Order__c
            FROM Standard_Onboarding_Step__mdt
            WHERE Active__c = true
            ORDER BY Order__c ASC
        ];

        Set<String> existingNames = new Set<String>();
        for (Onboarding_Step__c existingStep : [
            SELECT Name
            FROM Onboarding_Step__c
            WHERE Account__c = :accountId
        ]) {
            existingNames.add(existingStep.Name);
        }

        List<Onboarding_Step__c> stepsToCreate = new List<Onboarding_Step__c>();
        for (Standard_Onboarding_Step__mdt standardStep : standardSteps) {
            if (!existingNames.contains(standardStep.Step_Label__c)) {
                stepsToCreate.add(new Onboarding_Step__c(
                    Account__c = accountId,
                    Name = standardStep.Step_Label__c,
                    Order__c = standardStep.Order__c,
                    Status__c = 'Not started'
                ));
            }
        }

        if (!stepsToCreate.isEmpty()) {
            insert stepsToCreate;
        }
        return stepsToCreate.size();
    }

    @TestVisible
    private static Integer calculateProgressPercent(Integer doneSteps, Integer totalSteps) {
        if (totalSteps == null || totalSteps == 0) {
            return 0;
        }
        Decimal percent = (Decimal.valueOf(doneSteps == null ? 0 : doneSteps) / Decimal.valueOf(totalSteps)) * 100;
        return percent.setScale(0, RoundingMode.HALF_UP).intValue();
    }

    @TestVisible
    private static Boolean isStalled(Integer progressPercent, Datetime lastActivityDate, Datetime nowValue) {
        if (lastActivityDate == null || progressPercent == 100) {
            return false;
        }
        return lastActivityDate <= nowValue.addDays(-STALLED_DAYS);
    }

    private static void validateAccountId(Id accountId) {
        if (accountId == null || accountId.getSObjectType() != Account.SObjectType) {
            throw new AuraHandledException('A valid Account record Id is required.');
        }
    }

    private static String getStatusClass(String status) {
        if (status == 'Done') {
            return 'status-done';
        }
        if (status == 'Blocked') {
            return 'status-blocked';
        }
        if (status == 'In Progress') {
            return 'status-progress';
        }
        return 'status-not-started';
    }
}
