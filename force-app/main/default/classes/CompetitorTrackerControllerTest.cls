@isTest
private class CompetitorTrackerControllerTest {

    @TestSetup
    static void setup() {
        Competitor__c comp1 = new Competitor__c(Name = 'Competitor1', Industry__c = 'Software');
        Competitor__c comp2 = new Competitor__c(Name = 'Competitor2', Industry__c = 'Hardware');
        insert new List<Competitor__c>{ comp1, comp2 };

        Account acct = new Account(Name = 'Test Account');
        insert acct;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 4; i++) {
            opps.add(new Opportunity(
                Name = 'Opp ' + i,
                AccountId = acct.Id,
                StageName = 'Needs Analysis',
                CloseDate = Date.today().addDays(30),
                Amount = 1000 * (i + 1)
            ));
        }
        insert opps;
    }

    @isTest
    static void testSearchCompetitors_returnsMatches() {
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor1' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ comp.Id });

        Test.startTest();
        List<Competitor__c> results = CompetitorTrackerController.searchCompetitors('Competitor1');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one matching competitor');
    }

    @isTest
    static void testSearchCompetitors_returnsEmpty() {
        List<Competitor__c> results = CompetitorTrackerController.searchCompetitors('a');
        System.assertEquals(0, results.size(), 'Single character terms should not hit SOSL');
    }

    @isTest
    static void testLinkCompetitor_success() {
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor1' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        Opportunity_Competitor__c link = CompetitorTrackerController.linkCompetitor(
            opp.Id, comp.Id, 'High');
        Test.stopTest();

        System.assertNotEquals(null, link.Id, 'should be inserted');
        System.assertEquals('High', link.Threat_Level__c);
    }

    @isTest
    static void testLinkCompetitor_duplicate() {
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor1' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        CompetitorTrackerController.linkCompetitor(opp.Id, comp.Id, 'Low');

        Boolean threw = false;
        try {
            CompetitorTrackerController.linkCompetitor(opp.Id, comp.Id, 'Medium');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Linking the same competitor twice should throw');
    }

    @isTest
    static void testGetLinkedCompetitors_success() {
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor1' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        CompetitorTrackerController.linkCompetitor(opp.Id, comp.Id, 'Low');

        Test.startTest();
        List<Opportunity_Competitor__c> links =
            CompetitorTrackerController.getLinkedCompetitors(opp.Id);
        Test.stopTest();

        System.assertEquals(1, links.size());
    }

    @isTest
    static void testUpdateAndRemoveOpportunityCompetitor_success() {
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor1' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Opportunity_Competitor__c link =
            CompetitorTrackerController.linkCompetitor(opp.Id, comp.Id, 'Low');

        Test.startTest();
        CompetitorTrackerController.updateOpportunityCompetitor(link.Id, 'High', 'Price', 'Updated notes');
        CompetitorTrackerController.removeOpportunityCompetitor(link.Id);
        Test.stopTest();

        List<Opportunity_Competitor__c> remaining = [
            SELECT Id FROM Opportunity_Competitor__c WHERE Id = :link.Id
        ];
        System.assertEquals(0, remaining.size(), 'should be deleted');
    }

    @isTest
    static void testGetStats_mixedWinsAndLosses() {
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor2' LIMIT 1];
        List<Opportunity> opps = [SELECT Id, Amount FROM Opportunity ORDER BY Amount LIMIT 4];

        for (Opportunity o : opps) {
            CompetitorTrackerController.linkCompetitor(o.Id, comp.Id, 'Medium');
        }

        opps[0].StageName = 'Closed Won';
        opps[1].StageName = 'Closed Won';
        opps[2].StageName = 'Closed Lost';
        update opps;

        Test.startTest();
        CompetitorTrackerController.CompetitorStats stats =
            CompetitorTrackerController.getStats(comp.Id);
        Test.stopTest();

        System.assertEquals(4, stats.totalOpportunities);
        System.assertEquals(2, stats.wonCount);
        System.assertEquals(1, stats.lostCount);
        System.assertNotEquals(null, stats.avgDealSizeWon);
        System.assertNotEquals(null, stats.avgDealSizeLost);
    }

    @isTest
    static void testGetStats_noClosedOpportunities() {
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor1' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        CompetitorTrackerController.linkCompetitor(opp.Id, comp.Id, 'Low');

        Test.startTest();
        CompetitorTrackerController.CompetitorStats stats =
            CompetitorTrackerController.getStats(comp.Id);
        Test.stopTest();

        System.assertEquals(1, stats.totalOpportunities);
        System.assertEquals(null, stats.avgDealSizeWon);
        System.assertEquals(null, stats.avgDealSizeLost);
    }
}
