try {
    List<Account> accs = new List<Account>();
    for (Integer i = 0; i < 102; i++) {
        GovernorLimitCheck.checkAll('AccountTrigger');
        accs = [SELECT Id, Name FROM Account LIMIT 50];
    }

    GovernorLimitCheck.checkAll('AccountTrigger');
    update accs;
} catch (GovernorLimitCheck.GovernorLimitPreventedException ex) {
    System.debug('Operation halted: ' + ex.getMessage());
}
