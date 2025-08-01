public without sharing class GovernorLimitCheck {
    private static Map<String, Integer> getCurrentUsages() {
        return new Map<String, Integer>{
            'CPU_TIME' => Limits.getCpuTime(),
            'HEAP_SIZE' => Limits.getHeapSize(),
            'SOQL_QUERIES' => Limits.getQueries(),
            'SOQL_ROWS' => Limits.getQueryRows(),
            'DML_STATEMENTS' => Limits.getDmlStatements(),
            'DML_ROWS' => Limits.getDmlRows(),
            'CALL_OUTS' => Limits.getCallouts(),
            'EMAIL_INVOCATIONS' => Limits.getEmailInvocations(),
            'FUTURE_CALLS' => Limits.getFutureCalls(),
            'QUEUEABLE_JOBS' => Limits.getQueueableJobs()
        };
    }

    private static Map<String, Integer> getLimitMaximums() {
        return new Map<String, Integer>{
            'CPU_TIME' => Limits.getLimitCpuTime(),
            'HEAP_SIZE' => Limits.getLimitHeapSize(),
            'SOQL_QUERIES' => Limits.getLimitQueries(),
            'SOQL_ROWS' => Limits.getLimitQueryRows(),
            'DML_STATEMENTS' => Limits.getLimitDmlStatements(),
            'DML_ROWS' => Limits.getLimitDmlRows(),
            'CALL_OUTS' => Limits.getLimitCallouts(),
            'EMAIL_INVOCATIONS' => Limits.getLimitEmailInvocations(),
            'FUTURE_CALLS' => Limits.getLimitFutureCalls(),
            'QUEUEABLE_JOBS' => Limits.getLimitQueueableJobs()
        };
    }

    private static Map<String, Decimal> getThresholds() {
        Map<String, Decimal> out = new Map<String, Decimal>();
        if (Schema.sObjectType.GovernorLimitThreshold__mdt.isAccessible()) {
            for (GovernorLimitThreshold__mdt rec : [SELECT DeveloperName, Threshold__c FROM GovernorLimitThreshold__mdt]) {
                out.put(rec.DeveloperName, rec.Threshold__c);
            }
        } else {
            return new Map<String, Integer>{ 'DEFAULT' => 85 };
        }
        return out;
    }

    public static void checkAll(String contextHint) {
        // Avoid infinite recursion if this method itself fires events
        if (Limits.getLimitDmlRows() == Limits.getDmlRows()) {
            return;
        }

        Map<String, Integer> maxes = getLimitMaximums();
        Map<String, Integer> currents = getCurrentUsages();
        Map<String, Decimal> thresholds = getThresholds();

        LimitContext ctx = new LimitContext(currents, maxes, thresholds, contextHint);
        List<Exception_Log__e> events = createLimitEvents(ctx);

        if (!events.isEmpty()) {
            // One callout‑safe publish for all violations
            EventBus.publish(events);
            List<String> limitNames = new List<String>();
            for (Exception_Log__e event : events) {
                limitNames.add(event.Limit_Name__c);
            }
            throw new GovernorLimitPreventedException('Governor limit approaching: ' + String.join(limitNames, ','));
        }
    }

    private class LimitContext {
        public Map<String, Integer> currents;
        public Map<String, Integer> maxes;
        public Map<String, Decimal> thresholds;
        public String contextHint;

        public LimitContext(
            Map<String, Integer> currents,
            Map<String, Integer> maxes,
            Map<String, Decimal> thresholds,
            String contextHint
        ) {
            this.currents = currents;
            this.maxes = maxes;
            this.thresholds = thresholds;
            this.contextHint = contextHint;
        }
    }

    private static List<Exception_Log__e> createLimitEvents(LimitContext ctx) {
        List<Exception_Log__e> events = new List<Exception_Log__e>();
        for (String name : ctx.currents.keySet()) {
            Exception_Log__e event = checkLimitAndCreateEvent(name, ctx);
            if (event != null) {
                events.add(event);
            }
        }
        return events;
    }

    private static Exception_Log__e checkLimitAndCreateEvent(String name, LimitContext ctx) {
        Integer current = ctx.currents.get(name);
        Integer max = ctx.maxes.get(name);
        if (max == 0) {
            return null;
        }
        Decimal pctUsed = (Decimal.valueOf(current) / max) * 100;

        if (ctx.thresholds.containsKey(name)) {
            if (pctUsed >= ctx.thresholds.get(name)) {
                return new Exception_Log__e(
                    Limit_Name__c = name,
                    Usage__c = current,
                    Limit__c = max,
                    Triggered_On__c = ctx.contextHint,
                    Stacktrace__c = null,
                    Run_By_User_Id__c = UserInfo.getUserId()
                );
            }
        } else {
            Double defaultThreshold = ctx.thresholds.containsKey('DEFAULT') ? ctx.thresholds.get('DEFAULT') : 85;
            if (pctUsed > defaultThreshold) {
                return new Exception_Log__e(
                    Limit_Name__c = name,
                    Usage__c = current,
                    Limit__c = max,
                    Triggered_On__c = ctx.contextHint,
                    Stacktrace__c = null,
                    Run_By_User_Id__c = UserInfo.getUserId()
                );
            }
        }
        return null;
    }

    public class GovernorLimitPreventedException extends Exception {
    }
}
