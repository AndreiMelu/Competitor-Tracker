/**
 * Controller for the competitorTracker LWC.
 * All DML and SOQL/SOSL for the Competitor Tracker feature are here, called from the LWC's JavaScript via @AuraEnabled methods.
 * @author Andrei Melu
 * @date 2026-06-21
 */

public with sharing class CompetitorTrackerController {
    private static final String DUPLICATE_ERROR = 'This competitor is already linked to this opportunity.';
    private static final String MISSING_ID_ERROR = 'Missing record Id.';

    @AuraEnabled(cacheable=true)
    public static List<Competitor__c> searchCompetitors(String searchTerm) {
        String term = (searchTerm == null) ? '' : searchTerm.trim();

        if (term.length() < 2) {
            // Avoids SOSL calls on every keystroke before user has typed at least 2 characters.
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

    @AuraEnabled
    public static Opportunity_Competitor__c linkCompetitor(Id opportunityId, Id competitorId, String threatLevel) {
        if (opportunityId == null || competitorId == null) {
            throw new AuraHandledException('Opportunity and Competitor are required!');
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
            throw new AuraHandledException('Unable to link competitor: ' + e.getMessage());
        }

        return [
            SELECT Id, Threat_Level__c, Loss_Reason__c, Notes__c, Competitor__c, Competitor__r.Name, Competitor__r.Industry__c
            FROM Opportunity_Competitor__c
            WHERE Id = :link.Id
        ];
    }

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

    @AuraEnabled
    public static void updateOpportunityCompetitor(Id opportunityCompetitorId, String threatLevel, String lossReason, String notes) {
        if (opportunityCompetitorId == null) {
            throw new AuraHandledException(MISSING_ID_ERROR);
        }

        Opportunity_Competitor__c oc = new Opportunity_Competitor__c(Id = opportunityCompetitorId);
        oc.Threat_Level__c = threatLevel;
        oc.Loss_Reason__c = lossReason;
        oc.Notes__c = notes;

        try {
            update oc;
        } catch (DmlException e) {
            throw new AuraHandledException('Unable to update: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void removeOpportunityCompetitor(Id opportunityCompetitorId) {
        if (opportunityCompetitorId == null) {
            throw new AuraHandledException(MISSING_ID_ERROR);
        }
        try {
            delete new Opportunity_Competitor__c(Id = opportunityCompetitorId);
        } catch (DmlException e) {
            throw new AuraHandledException('Unable to remove competitor link: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static CompetitorStats getStats(Id competitorId) {
        if (competitorId == null) {
            throw new AuraHandledException(MISSING_ID_ERROR);
        }

        Integer wonCount = 0;
        Integer lostCount = 0;
        Decimal wonAmountTotal = 0;
        Integer wonAmountCount = 0;
        Decimal lostAmountTotal = 0;
        Integer lostAmountCount = 0;

        List<Opportunity_Competitor__c> oppCompetitorList = [
            SELECT Opportunity__c, Opportunity__r.StageName, Opportunity__r.IsWon, Opportunity__r.IsClosed, Opportunity__r.Amount
            FROM Opportunity_Competitor__c
            WHERE Competitor__c = :competitorId
        ];

        CompetitorStats stats = new CompetitorStats();
        stats.totalOpportunities = oppCompetitorList.size();

        for (Opportunity_Competitor__c oppCompetitor : oppCompetitorList) {
            Opportunity opp = oppCompetitor.Opportunity__r;
            if (opp == null || !opp.IsClosed) {
                continue;
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
        stats.wonCount = wonCount;
        stats.lostCount = lostCount;
        Integer totalCount = wonCount + lostCount;
        stats.winRate = (totalCount == 0)
            ? null
            : (Decimal.valueOf(wonCount) / totalCount).setScale(4);
        stats.avgDealSizeWon = (wonAmountCount == 0)
            ? null
            : (wonAmountTotal / wonAmountCount).setScale(2);
        stats.avgDealSizeLost = (lostAmountCount == 0)
            ? null
            : (lostAmountTotal / lostAmountCount).setScale(2);

        return stats;
    }

    public class CompetitorStats {
        @AuraEnabled public Integer totalOpportunities;
        @AuraEnabled public Integer wonCount;
        @AuraEnabled public Integer lostCount;
        @AuraEnabled public Decimal winRate;
        @AuraEnabled public Decimal avgDealSizeWon;
        @AuraEnabled public Decimal avgDealSizeLost;
    }
}
