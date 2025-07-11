public class GovernorLimitCheck {
    private static Map<String, Integer> getCurrentUsages() {
        return new Map<String, Integer>{
            'CPU_TIME'          => Limits.getCpuTime(),
            'HEAP_SIZE'         => Limits.getHeapSize(),
            'SOQL_QUERIES'      => Limits.getQueries(),
            'SOQL_ROWS'         => Limits.getQueryRows(),
            'DML_STATEMENTS'    => Limits.getDmlStatements(),
            'DML_ROWS'          => Limits.getDmlRows(),
            'CALL_OUTS'         => Limits.getCallouts(),
            'EMAIL_INVOCATIONS' => Limits.getEmailInvocations(),
            'FUTURE_CALLS'      => Limits.getFutureCalls(),
            'QUEUEABLE_JOBS'    => Limits.getQueueableJobs()
        };
    }
    
    private static Map<String, Integer> getLimitMaximums() {
        return new Map<String, Integer>{
            'CPU_TIME'          => Limits.getLimitCpuTime(),
            'HEAP_SIZE'         => Limits.getLimitHeapSize(),
            'SOQL_QUERIES'      => Limits.getLimitQueries(),
            'SOQL_ROWS'         => Limits.getLimitQueryRows(),
            'DML_STATEMENTS'    => Limits.getLimitDmlStatements(),
            'DML_ROWS'          => Limits.getLimitDmlRows(),
            'CALL_OUTS'         => Limits.getLimitCallouts(),
            'EMAIL_INVOCATIONS' => Limits.getLimitEmailInvocations(),
            'FUTURE_CALLS'      => Limits.getLimitFutureCalls(),
            'QUEUEABLE_JOBS'    => Limits.getLimitQueueableJobs()
        };
    }
    
    private static Map<String,Decimal> getThresholds() {
        Map<String,Decimal> out = new Map<String,Decimal>();
        for (GovernorLimitThreshold__mdt rec :
             [SELECT DeveloperName, Threshold__c FROM GovernorLimitThreshold__mdt]) {
            out.put(rec.DeveloperName, rec.Threshold__c);
        }
        return out;
    }

    public static void checkAll(String contextHint) {
        // Avoid infinite recursion if this method itself fires events
                                System.debug('Hello World');
        if (Limits.getLimitDmlRows() == Limits.getDmlRows())
            return; 

        Map<String, Integer> maxes     = getLimitMaximums();
        Map<String, Integer> currents  = getCurrentUsages();
        Map<String, Decimal> thresholds = getThresholds();

        List<Exception_Log__e> events = new List<Exception_Log__e>();

        for (String name : currents.keySet()) {
            Integer current = currents.get(name);
            Integer max     = maxes.get(name);
            if (max == 0) continue;

            Decimal pctUsed = (Decimal.valueOf(current) / max) * 100;

            if (thresholds.containsKey(name) && pctUsed >= thresholds.get(name)) {
                events.add(new Exception_Log__e(
                    Limit_Name__c   = name,
                    Usage__c        = current,
                    Limit__c        = max,
                    Triggered_On__c = contextHint,
                    Stacktrace__c   = null
                ));
            }
        }
        if (!events.isEmpty()) {
            // One callout‑safe publish for all violations
            EventBus.publish(events);
            String limitNames = '';
            for(Exception_Log__e event : events){
                limitNames += event.Limit_Name__c + ', ';
            }
            throw new GovernorLimitPreventedException('Governor limit approaching: ' + limitNames);
        }
    }

    public class GovernorLimitPreventedException extends Exception {}

}