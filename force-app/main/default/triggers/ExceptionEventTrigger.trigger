trigger ExceptionEventTrigger on Exception_Log__e(after insert) {
    List<Exception__c> logs = new List<Exception__c>();
    List<Id> runByUserIds = new List<Id>();
    for (Exception_Log__e evt : Trigger.new) {
        runByUserIds.add(evt.Run_By_User_Id__c);
    }
    Map<Id, User> users = new Map<Id, User>(
        [
            SELECT Id, Name
            FROM User
            WHERE Id IN :runByUserIds
        ]
    );
    for (Exception_Log__e evt : Trigger.new) {
        logs.add(
            new Exception__c(
                Name = users.get(evt.Run_By_User_Id__c).Name + ' - ' + evt.Limit_Name__c,
                Limit_Name__c = evt.Limit_Name__c,
                Used__c = evt.Usage__c,
                Max_Limit__c = evt.Limit__c,
                Triggered_On__c = evt.Triggered_On__c,
                Run_By__c = evt.Run_By_User_Id__c
            )
        );
    }

    insert logs;
}
