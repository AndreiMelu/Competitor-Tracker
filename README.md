# Competitor Tracker — Sales Cloud

A Lightning Web Component for the Opportunity record page that lets reps search
for and link known competitors, track threat level and notes per deal, and see
historical win/loss performance against each competitor.

## What's included

```
force-app/main/default/
├── objects/
│   ├── Competitor__c/                       Standalone competitor object
│   ├── Opportunity_Competitor__c/           Junction object (Opportunity <-> Competitor)
│   └── Opportunity/
│       ├── fields/Competitor_Count__c       Roll-up COUNT of linked competitors
│       └── validationRules/                 Gates Needs Analysis -> Proposal/Price Quote
├── classes/
│   ├── CompetitorTrackerController.cls      All SOQL/SOSL/DML for the feature
│   └── CompetitorTrackerControllerTest.cls  Unit tests (8 methods, all paths)
├── lwc/competitorTracker/                   The LWC itself
└── permissionsets/Competitor_Tracker_Access Grants object/field/Apex access
```

## Deploying to your sandbox

You'll need the [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)
(`sf`) installed and authenticated to your sandbox/Dev Hub.

```bash
# 1. Authenticate (opens a browser login)
sf org login web --alias myPlayground --instance-url https://test.salesforce.com

# 2. From the project root, deploy everything
sf project deploy start --target-org myPlayground

# 3. Assign the permission set to yourself (or any test user)
sf org assign permset --name Competitor_Tracker_Access --target-org myPlayground

# 4. Run the tests (optional but recommended)
sf apex run test --tests CompetitorTrackerControllerTest --target-org myPlayground --result-format human
```

Alternatively, open the project folder in VS Code with the **Salesforce
Extensions Pack** installed, authenticate via the command palette, then
right-click `force-app` → **SFDX: Deploy Source to Org**.

### After deploying

The component isn't placed on the page layout automatically (Lightning page
assignments aren't part of standard metadata deploys in this project). To add
it:

1. Open any Opportunity record → **Setup gear → Edit Page**.
2. Drag **Competitor Tracker** from the Custom components list onto the page.
3. Save and activate the page (org default, or for the relevant app/profile).

You'll also want a few `Competitor__c` records to search against — easiest via
the Competitors tab/related list or Data Import Wizard.

## Design decisions & trade-offs

- **Card layout over `lightning-datatable`.** The spec allows either. Cards
  made it straightforward to combine inline edit, a truncated-notes view, and
  an expandable stats panel in one row without fighting `lightning-datatable`'s
  draft-values API for non-table content like the stats grid.
- **SOSL over LIKE for search.** SOSL needed `Test.setFixedSearchResults` for
  test coverage but scales better than `LIKE '%term%'` once there are many
  competitors, and naturally tokenizes multi-word names. A 2-character minimum
  avoids firing SOSL on every keystroke before the user has typed anything
  meaningful.
- **Duplicate prevention is enforced in Apex, not a unique field.** A
  formula-based composite key on a junction object isn't eligible for a
  `unique` constraint in Salesforce, so `linkCompetitor` checks for an
  existing row before insert and also catches the rare DML race. If this
  needed to be bulletproof under concurrent inserts, a Duplicate Rule on
  `Opportunity_Competitor__c` (Opportunity + Competitor) would be the next
  step.
- **Win rate / average deal size only count *closed* opportunities.**
  Open opportunities linked to a competitor count toward "Total
  Opportunities" but are excluded from win rate and average deal size, since
  they don't have a final outcome yet. Both metrics return `null` (rendered as
  `N/A`) rather than `0` when there's no decided data, so "no data" isn't
  visually indistinguishable from "always lost."
- **Validation rule uses a roll-up summary, not Apex.** Because
  `Opportunity__c` on the junction object is a **Master-Detail** field (not a
  Lookup), a declarative roll-up (`Competitor_Count__c`, COUNT) is available
  on Opportunity, and the validation rule reads that directly — no trigger
  needed. The rule only fires on the specific `Needs Analysis` →
  `Proposal/Price Quote` transition (checked via `PRIORVALUE`), so reps moving
  between earlier stages, or already past Proposal, are never blocked.
  Stage API names are assumed to match Salesforce's standard defaults; adjust
  the two `ISPICKVAL` literals in the validation rule if your org uses custom
  stage names.
- **Picklist options are hardcoded in the LWC** (Threat Level, Loss Reason)
  rather than fetched via the UI API's picklist endpoints. This keeps the
  component simpler and avoids an extra wire/Apex round trip, at the cost of
  needing a manual update if the picklist values change. For a component
  expected to evolve, `getPicklistValuesByRecordType` would be the more
  robust choice.
- **Accordion-style row expansion.** Only one stats panel is open at a time.
  This was a UX call to keep the page from getting tall when a deal is facing
  several competitors; it'd be a one-line change to allow multiple rows open
  simultaneously if preferred.
- **`with sharing` throughout**, and the permission set grants object/field
  access without `Modify All` — access decisions stay governed by the running
  user's actual sharing/visibility rather than the controller bypassing it.

## Apex test coverage

`CompetitorTrackerControllerTest` covers: search (match + below-minimum-length
short-circuit), link (success + server-side duplicate rejection), read,
update, delete, and stats for both a mixed win/loss competitor and a
competitor with no closed opportunities (verifying the null/divide-by-zero
handling explicitly).

## Known gaps / next steps

- No Lightning App Builder page metadata is included, since page assignment
  is environment-specific (see "After deploying" above).
- No CI config (e.g. GitHub Actions running `sf apex run test`) is included —
  worth adding if this moves beyond a take-home exercise.
- Competitor records have no de-duplication of their own; two `Competitor__c`
  rows named "Acme" would both be linkable. Out of scope per the assessment,
  but a real implementation would likely want a duplicate rule here too.
