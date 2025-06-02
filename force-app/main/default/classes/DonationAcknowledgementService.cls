public with sharing class DonationAcknowledgementService {
    // Wrapper class for Invocable input
    public class OpportunityIdWrapper {
        @InvocableVariable(required=true)
        public List<Id> opportunityIds;
    }

    // Wrapper class for Invocable output
    public class AckResultWrapper {
        @InvocableVariable
        public String result;
    }

    /**
     * Shared logic to process Opportunities by Ids
     */
    private static List<Opportunity> getOpportunitiesByIds(List<Id> idList) {
        if (idList == null || idList.isEmpty()) {
            return new List<Opportunity>();
        }
        return [
            SELECT Id, Name, Amount, StageName, CloseDate, AccountId, ContactId
            FROM Opportunity
            WHERE Id IN :idList
        ];
    }

    /**
     * Invocable method for Flows and list view buttons
     * @param inputList List of OpportunityIdWrapper
     * @return List of AckResultWrapper with status messages
     */
    @InvocableMethod(label='Send Donation Acknowledgements' description='Sends acknowledgement emails for selected Opportunities and creates EmailMessage records.')
    public static List<AckResultWrapper> sendAcknowledgementsInvocable(List<OpportunityIdWrapper> inputList) {
        List<Id> idList = new List<Id>();
        for (OpportunityIdWrapper w : inputList) {
            if (w != null && w.opportunityIds != null) {
                for (Id idVal : w.opportunityIds) {
                    if (idVal != null) {
                        idList.add(idVal);
                    }
                }
            }
        }
        List<Opportunity> opps = getOpportunitiesByIds(idList);
        List<AckResultWrapper> results = new List<AckResultWrapper>();
        AckResultWrapper res = new AckResultWrapper();
        if (opps.isEmpty()) {
            res.result = 'No Opportunity IDs provided.';
        } else {
            // TODO: Process opps (send emails, create EmailMessage records)
            res.result = 'sendAcknowledgements called with ' + opps.size() + ' Opportunities.';
        }
        System.debug(LoggingLevel.INFO, res.result);
        results.add(res);
        return results;
    }

    /**
     * AuraEnabled method for LWC/Aura use
     */
    @AuraEnabled
    public static String sendAcknowledgements(List<Id> idList) {
        List<Opportunity> opps = getOpportunitiesByIds(idList);
        if (opps.isEmpty()) {
            return 'No Opportunity IDs provided.';
        }
        // TODO: Process opps (send emails, create EmailMessage records)
        return 'sendAcknowledgements called with ' + opps.size() + ' Opportunities.';
    }
}