@IsTest
private class PS_AssistantClaudeTest {

    private class ClaudeMock implements HttpCalloutMock {
        Integer status;
        String body;
        ClaudeMock(Integer status, String body) { this.status = status; this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('callout:Claude_API/v1/messages', req.getEndpoint());
            Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assertEquals('claude-opus-5-5', sent.get('model'));
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void setup() {
        insert new HR_Policy__c(Name = 'Leave Policy', Category__c = 'Leave', Active__c = true, Version__c = '3',
            Policy_Body__c = 'Employees receive 12 casual leaves per year. Unused casual leave lapses at year end.');
    }

    @IsTest
    static void usesClaudeWhenConfigured() {
        PS_AssistantController.forceClaude = true;
        Test.setFixedSearchResults(new List<Id>{ [SELECT Id FROM HR_Policy__c LIMIT 1].Id });
        Test.setMock(HttpCalloutMock.class, new ClaudeMock(200,
            '{"stop_reason":"end_turn","content":[{"type":"thinking","thinking":""},{"type":"text","text":"Per the Leave Policy you get 12 casual leaves."}]}'));
        Test.startTest();
        PS_AssistantController.Answer a = PS_AssistantController.ask('How many casual leaves do I get?');
        Test.stopTest();
        System.assert(a.usedClaude);
        System.assertEquals('Per the Leave Policy you get 12 casual leaves.', a.text);
    }

    @IsTest
    static void fallsBackOnRefusalOrError() {
        PS_AssistantController.forceClaude = true;
        Test.setFixedSearchResults(new List<Id>{ [SELECT Id FROM HR_Policy__c LIMIT 1].Id });
        Test.setMock(HttpCalloutMock.class, new ClaudeMock(200, '{"stop_reason":"refusal","content":[]}'));
        Test.startTest();
        PS_AssistantController.Answer a = PS_AssistantController.ask('What happens to unused casual leave?');
        Test.stopTest();
        System.assert(!a.usedClaude);
        System.assert(a.text.contains('Leave Policy'), a.text);
    }

    @IsTest
    static void fallsBackOnHttpError() {
        Test.setMock(HttpCalloutMock.class, new ClaudeMock(500, '{"error":"x"}'));
        System.assertEquals(null, PS_AssistantController.askClaude('hi', new List<HR_Policy__c>()));
    }
}
