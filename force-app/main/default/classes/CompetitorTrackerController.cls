/**
 * Controller for the competitorTracker LWC.
 * All DML and SOQL/SOSL for the Competitor Tracker feature lives here so the
 * component never touches data directly.
 */
public with sharing class CompetitorTrackerController {

    private static final String DUPLICATE_ERROR =
        'This competitor is already linked to this opportunity.';

    // ---------------------------------------------------------------
    // Search
    // ---------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<Competitor__c> searchCompetitors(String searchTerm) {
        String term = (searchTerm == null) ? '' : searchTerm.trim();

        if (term.length() < 2) {
            // Avoids noisy/erroring SOSL calls on every keystroke before the
            // user has typed anything meaningful.
            return new List<Competitor__c>();
        }

        String soslTerm = String.escapeSingleQuotes(term) + '*';

        List<List<SObject>> results = [
            FIND :soslTerm IN NAME FIELDS 
            RETURNING Competitor__c(Id, Name, Industry__c, Website__c
            ORDER BY Name)
        ];

        return (List<Competitor__c>) results[0];
    }

    // ---------------------------------------------------------------
    // Link
    // ---------------------------------------------------------------
    @AuraEnabled
    public static Opportunity_Competitor__c linkCompetitor(
        Id opportunityId, Id competitorId, String threatLevel) {

        if (opportunityId == null || competitorId == null) {
            throw new AuraHandledException('Opportunity and Competitor are required.');
        }

        Integer existing = [
            SELECT COUNT()
            FROM Opportunity_Competitor__c
            WHERE Opportunity__c = :opportunityId AND Competitor__c = :competitorId
        ];

        if (existing > 0) {
            throw new AuraHandledException(DUPLICATE_ERROR);
        }

        Opportunity_Competitor__c link = new Opportunity_Competitor__c(
            Opportunity__c = opportunityId,
            Competitor__c = competitorId,
            Threat_Level__c = threatLevel
        );

        try {
            insert link;
        } catch (DmlException e) {
            // Belt-and-braces: covers the (rare) race condition between the
            // existence check above and the insert itself.
            if (e.getMessage().contains('DUPLICATE_VALUE') || e.getMessage().contains('UNIQUE')) {
                throw new AuraHandledException(DUPLICATE_ERROR);
            }
            throw new AuraHandledException('Unable to link competitor: ' + e.getMessage());
        }

        return [
            SELECT Id, Threat_Level__c, Loss_Reason__c, Notes__c, Competitor__c, Competitor__r.Name, Competitor__r.Industry__c
            FROM Opportunity_Competitor__c
            WHERE Id = :link.Id
        ];
    }

    // ---------------------------------------------------------------
    // Read
    // ---------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<Opportunity_Competitor__c> getLinkedCompetitors(Id opportunityId) {
        if (opportunityId == null) {
            return new List<Opportunity_Competitor__c>();
        }

        return [
            SELECT Id, Threat_Level__c, Loss_Reason__c, Notes__c, Competitor__c, Competitor__r.Name, Competitor__r.Industry__c, Competitor__r.Website__c
            FROM Opportunity_Competitor__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY Competitor__r.Name
        ];
    }

    // ---------------------------------------------------------------
    // Update
    // ---------------------------------------------------------------
    @AuraEnabled
    public static void updateLink(Id linkId, String threatLevel, String lossReason, String notes) {
        if (linkId == null) {
            throw new AuraHandledException('Missing record Id.');
        }

        Opportunity_Competitor__c oc = new Opportunity_Competitor__c(Id = linkId);
        oc.Threat_Level__c = threatLevel;
        oc.Loss_Reason__c = lossReason;
        oc.Notes__c = notes;

        try {
            update oc;
        } catch (DmlException e) {
            throw new AuraHandledException('Unable to update link: ' + e.getMessage());
        }
    }

    // ---------------------------------------------------------------
    // Remove
    // ---------------------------------------------------------------
    @AuraEnabled
    public static void removeLink(Id linkId) {
        if (linkId == null) {
            throw new AuraHandledException('Missing record Id.');
        }
        try {
            delete new Opportunity_Competitor__c(Id = linkId);
        } catch (DmlException e) {
            throw new AuraHandledException('Unable to remove link: ' + e.getMessage());
        }
    }

    // ---------------------------------------------------------------
    // Stats
    // ---------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static CompetitorStats getStats(Id competitorId) {
        if (competitorId == null) {
            throw new AuraHandledException('Missing competitor Id.');
        }

        List<Opportunity_Competitor__c> links = [
            SELECT Opportunity__c, Opportunity__r.StageName, Opportunity__r.IsWon, Opportunity__r.IsClosed, Opportunity__r.Amount
            FROM Opportunity_Competitor__c
            WHERE Competitor__c = :competitorId
        ];

        CompetitorStats stats = new CompetitorStats();
        stats.totalOpportunities = links.size();

        Integer wonCount = 0;
        Integer lostCount = 0;
        Decimal wonAmountTotal = 0;
        Integer wonAmountCount = 0;
        Decimal lostAmountTotal = 0;
        Integer lostAmountCount = 0;

        for (Opportunity_Competitor__c link : links) {
            Opportunity opp = link.Opportunity__r;
            if (opp == null || !opp.IsClosed) {
                continue; // only Closed Won/Lost opps count toward win rate
            }
            if (opp.IsWon) {
                wonCount++;
                if (opp.Amount != null) {
                    wonAmountTotal += opp.Amount;
                    wonAmountCount++;
                }
            } else {
                lostCount++;
                if (opp.Amount != null) {
                    lostAmountTotal += opp.Amount;
                    lostAmountCount++;
                }
            }
        }

        Integer decidedCount = wonCount + lostCount;
        stats.winRate = (decidedCount == 0)
            ? null
            : (Decimal.valueOf(wonCount) / decidedCount).setScale(4);

        stats.wonCount = wonCount;
        stats.lostCount = lostCount;
        stats.avgDealSizeWon = (wonAmountCount == 0)
            ? null
            : (wonAmountTotal / wonAmountCount).setScale(2);
        stats.avgDealSizeLost = (lostAmountCount == 0)
            ? null
            : (lostAmountTotal / lostAmountCount).setScale(2);

        return stats;
    }

    // ---------------------------------------------------------------
    // Wrapper
    // ---------------------------------------------------------------
    public class CompetitorStats {
        @AuraEnabled public Integer totalOpportunities;
        @AuraEnabled public Integer wonCount;
        @AuraEnabled public Integer lostCount;
        @AuraEnabled public Decimal winRate;          // 0..1, null when there are no closed opps
        @AuraEnabled public Decimal avgDealSizeWon;   // null when there are no won amounts
        @AuraEnabled public Decimal avgDealSizeLost;  // null when there are no lost amounts
    }
}
