# Competitor Tracker

## What is this?
This is a new feature built directly into your Salesforce Opportunity pages. It gives your sales reps a dedicated place to track which competitors they're facing on each deal: how big of a threat they are, any notes about how the deal is playing out, and a quick look at how we've historically done against that competitor across all of our opportunities.

## What can sales reps do with it?
When a rep opens any Opportunity in Salesforce, they'll see a ”Competitor Tracker panel” on the page. From there they can:

**Search and add competitors**
Start typing a competitor's name and matching results appear automatically. 
Select one, set a threat level (Low, Medium, or High), and link it to the deal in one click.

**See all competitors on a deal at a glance**
Every competitor linked to that opportunity shows up as a card with their name, threat level and any notes the sales rep added.

**Edit on the fly**
They can update the threat level, add a loss reason (Price, Features, Relationship, Other), or write notes directly from the card added on the page.

**Remove a competitor**
If a competitor drops out of a deal, the rep can remove them. There's a confirmation step so nothing gets deleted by accident.

**See historical performance against each competitor**
Click the arrow next to any competitor and a stats panel expands showing:
- How many opportunities they've faced that competitor in total
- Our win rate against them (only counting deals that are actually closed)
- Our average deal size (when we win / when we lose against them)

This gives reps real context going into a deal — not just "we've competed against **Competitor X** before" but "we've faced **Competitor X** 14 times and we win 60% of the time, but our average deal is smaller when we lose, which usually means price was the issue."

**Stage gate — you can't skip ahead without logging a competitor**
Created a rule that prevents reps from moving an opportunity from *Needs Analysis* (or earlier stage) to *Proposal/Price Quote* (or later stage) unless at least one competitor has been logged. This is intentional because before putting a proposal, we should know who we are against.

## How do I get this set up?
This is handled by your **Salesforce administrator or developer**.
If you are nota tehnical person, please forward this file and ask them to deploy it and assign the **Competitor Tracker Access** permission set to the relevant users.
After that, make sure competitors are already in the system as **Competitor records** so sales reps can find them when they search. Bulk-import these records if you there is a list.

## Technical setup (for Salesforce admin/developer)
Install Salesforce CLI and connect to the wanted org.
- Connect to specific org (environment)
- Deploy everything
- Give users access

After deploying, go to Opportunity record -> Setup -> Edit Page -> drag the **Competitor Tracker** component onto the layout → Save and Activate.

## TODO

1. Build a Competitor Intelligence Hub
Competitors exist as simple records with a name and an industry. 
We could expand each competitor's profile to include their pricing, their key product, known weaknesses, and links to sales enablement materials. 
Reps would have everything they need in one place.

2. Reports and dashboards for steakholders/leadership
Data is now structured in Salesforce, which means it can be reported like:
- Which competitors show up most often across our pipeline
- Our win rate broken down by competitor, by region, or by sales rep
- Deals where High-threat competitors are present and where there is no move in 30+ days

This kind of visibility helps sales leadership understand the hole competitive landscape, not just deal by deal.

3. Add note to link competitor
When linking a competitor to an opportunity, the sales rep should be able to also add a note at the same time.

3. Competitive alerts for leadership
If a competitor is flagged as High threat on a deal, we could trigger an automatic notification to the opportunity owner's manager. 
This gives leadership a chance to get involved early.

4. Competitor deduplication
If the team is large enough, eventually end up with duplicate competitor records. Ex: one person enters "Salesforce" and another enters "Salesforce.com". 
Adding a duplicate prevention rule on the competitor records would keep the data clean without relying on everyone will search first.



## Technical note
Since Opportunity_Competitor__c is Master-Detail relationship, can't have a different record sharing than its parent (Opportunity).
Using Master-Detail against Lookup because of using Competitors card on Opportunity page and need to have a roll-up summary field.