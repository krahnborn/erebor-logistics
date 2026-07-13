@IsTest
private class MerchantOnboardingControllerTest {
    @IsTest
    static void getOnboardingSummaryCalculatesProgressAndBlockedSteps() {
        Account account = new Account(Name = 'Bree Trading House');
        insert account;

        insert new List<Onboarding_Step__c>{
            new Onboarding_Step__c(
                Account__c = account.Id,
                Name = 'Application Received',
                Order__c = 10,
                Status__c = 'Done',
                Completed_Date__c = Date.today()
            ),
            new Onboarding_Step__c(
                Account__c = account.Id,
                Name = 'KYC Pending',
                Order__c = 20,
                Status__c = 'Blocked',
                Blocked_Reason__c = 'Waiting on beneficial ownership documents.'
            ),
            new Onboarding_Step__c(
                Account__c = account.Id,
                Name = 'Trading Setup',
                Order__c = 30,
                Status__c = 'Not started'
            )
        };

        Test.startTest();
        MerchantOnboardingController.OnboardingSummary summary =
            MerchantOnboardingController.getOnboardingSummary(account.Id);
        Test.stopTest();

        System.assertEquals(3, summary.totalSteps);
        System.assertEquals(1, summary.doneSteps);
        System.assertEquals(1, summary.blockedSteps);
        System.assertEquals(33, summary.progressPercent);
        System.assertEquals(false, summary.stalled);
        System.assertEquals('Application Received', summary.steps[0].name);
        System.assertEquals('status-blocked', summary.steps[1].statusClass);
    }

    @IsTest
    static void createMissingStandardStepsIsIdempotent() {
        Account account = new Account(Name = 'Dale Market');
        insert account;

        Test.startTest();
        Integer firstCreated = MerchantOnboardingController.createMissingStandardSteps(account.Id);
        Integer secondCreated = MerchantOnboardingController.createMissingStandardSteps(account.Id);
        Test.stopTest();

        System.assert(firstCreated > 0, 'Expected standard custom metadata to create steps.');
        System.assertEquals(0, secondCreated);
        System.assertEquals(firstCreated, [
            SELECT COUNT()
            FROM Onboarding_Step__c
            WHERE Account__c = :account.Id
        ]);
    }

    @IsTest
    static void stalledHelperHonorsThreeDayThresholdAndCompletion() {
        Datetime nowValue = Datetime.newInstance(2026, 7, 13, 12, 0, 0);

        System.assertEquals(true, MerchantOnboardingController.isStalled(
            50,
            nowValue.addDays(-3),
            nowValue
        ));
        System.assertEquals(false, MerchantOnboardingController.isStalled(
            100,
            nowValue.addDays(-10),
            nowValue
        ));
        System.assertEquals(false, MerchantOnboardingController.isStalled(
            50,
            nowValue.addDays(-2),
            nowValue
        ));
    }
}
