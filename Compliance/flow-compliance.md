# Flow Coding Compliance Standard

## §0 Purpose & Scope

This standard defines the mandatory engineering rules for building and maintaining Salesforce Flows. Flow is a primary automation layer in most orgs, and undisciplined Flow design produces non-deterministic results, silent failures, and governor-limit breaks that only surface under bulk load. These rules exist so that any reviewer can read, reason about, and safely deploy a Flow regardless of who authored it.

**Applies to:** all Flows owned by this team — custom, in-house automation across all types: record-triggered, screen, autolaunched, scheduled, platform-event, and subflows.

**Exempt:** third-party managed-package Flows (installed AppExchange packages, identifiable by a namespaced API prefix such as `pse__` or `ffscpq__`) are not modified by this team and are excluded from the version-hygiene rules (§1.6). If your team forks or extends a managed package, the forked Flows are in scope.

"Must" denotes a hard requirement enforced at code review and deployment. "Should" denotes a strong default that requires a documented reason to deviate.

## §1 Flow Builder Standards

**1.1 Auto-Layout is mandatory.** Every Flow must be built and maintained in Auto-Layout. Free-Form is permitted only as a temporary working mode during a large structural reorganization and must be converted back to Auto-Layout before the version is activated or committed. Auto-Layout produces a consistent, top-to-bottom structure that any reviewer can read, and Salesforce's current Builder tooling (insertion points, copy/paste, tooltips) assumes it.

**1.2 Latest Flow API version is mandatory.** Every Flow must be saved at the latest Flow API (run-time) version available in the org — the current default in Flow Builder. Flows must not be left pinned to an older API version. State this as an evergreen requirement — "latest available," not a fixed number — because the target advances with each release. Over time an org accumulates Flows spanning many API versions; any Flow below the current default must be brought current by saving a new version at the latest execution API version. A Flow displaying API version 0 (authored before 50.0) must be remediated by saving a new version at a current execution API version.

**1.3 A version description is mandatory.** Every Flow version must carry a Description. Use a single-line format `YYYY-MM-DD: summary` (no ticket IDs or other memos). This gives each version a human-readable change note in the version list, so the version history is self-documenting without depending on inline element notes.

**1.4 Consistent naming.** Adopt one convention for every Flow, resource, and element:
- Flow API names begin with the object or domain name so all automation on an object sorts together and duplicates are visible before a new Flow is added.
- Resources (variables, formulas, constants) are nouns; Elements (actions, DML) are verbs.
- Decisions are phrased as questions; their Outcomes are named as the answers and prefixed with the Decision name (e.g. `Is_Renewal_True`).
- Loops are named `Each_<Record>`.

**1.5 No hardcoded Ids.** Flows must never contain hardcoded record Ids or RecordType Ids. Resolve Ids at run time via a Get Records filtered on a stable DeveloperName/API name, or read them from Custom Metadata Types (preferred), Custom Labels, or Custom Settings. Hardcoded Ids diverge between sandbox and production and break on refresh.

**1.6 Remove Obsolete and InvalidDraft versions.** Only a single validated Active version per Flow may be deployed to a target org. Obsolete and InvalidDraft versions must not accumulate — orgs tend to carry a backlog of committed Obsolete and InvalidDraft versions that must be cleaned up. Retain the Active version plus at most a small, fixed number (default: 2) of the most recent inactive versions for rollback; delete the rest. Never delete the Active version or a higher-numbered version awaiting review. InvalidDraft means the Flow failed validation and would not run correctly, so it must never be shipped. Obsolete versions also block removal of the fields, classes, and components they reference, so cleanup is a dependency-management requirement, not just tidiness.

**1.7 One orchestrator Flow per object per trigger context.** For record-triggered automation, the default architecture should be a single record-triggered Flow per object per context — **one before-save orchestrator and one after-save orchestrator per object** — rather than multiple independent record-triggered Flows on the same object. This is the first design decision when adding record-triggered logic to an object: route the work through the existing two entry points, do not add a competing Flow. Execution order among multiple record-triggered Flows on the same object and context **can** be controlled with each Flow's **Trigger Order** property (a value of 1–2000; Flows run low number first, ties and unset values run last in no guaranteed order — available since Spring '22 / API 55.0), but relying on it still scatters the object's logic across many Flows, each carrying its own entry criteria and order number to keep in sync, and every new Flow risks renumbering. A single entry point per timing keeps the logic **and** its ordering in one visible, reviewable place — element order within the orchestrator *is* the execution order. Within each orchestrator, branch with Decision elements and delegate each unit of work to a subflow so logic stays modular and independently testable. Separate responsibilities by timing: the **before-save** orchestrator handles same-record field defaulting and validation with no DML (cheapest and fastest); the **after-save** orchestrator handles related-record DML, asynchronous work, and messaging. Because before-save Flows cannot call subflows (§3.5), the before-save orchestrator organizes its branches inline rather than via subflows. Where a deliberate multi-Flow design is chosen instead (the documented deviation this "should" allows), every such Flow must set an explicit Trigger Order — never leave ordering to chance.

## §2 Bulkification & Performance

**2.1 No data elements in loops.** Never place a Get Records, Create Records, Update Records, or Delete Records element inside a Loop. Any data element inside a loop is multiplied by the iteration count, so 200 records can produce up to 200 SOQL/DML operations and breach governor limits.

**2.2 Use the collection pattern.** Get all needed records **before** the loop; inside the loop use only Assignment elements to add modified records to a record collection variable; run **one** Update/Create/Delete on that collection **after** the loop exits. When fetching related records, use a single Get with an In/collection filter rather than looping to fetch one at a time.

**2.3 Respect the shared per-transaction limits.** Flow draws down the same governor counters as all Apex and automation in the transaction: 100 SOQL queries, 50,000 records retrieved, 150 DML statements, 10,000 DML rows. Design so a 200-record bulk save cannot approach these ceilings. Minimize Get Records elements — query once, reuse via variables, and merge multiple updates to the same record into a single DML.

**2.4 Offload heavy work to a new transaction — default to a Scheduled Path.** Any work that does not need to complete in real time (synchronously with the user's save) must be moved off the triggering transaction. A **Scheduled Path is the default vehicle**: schedule the heavy branch to run moments later (or on a set time), which starts a new transaction and resets governor counters. Reserve synchronous, in-transaction processing only for logic whose result the user must see reflected immediately on save. A Pause element or a screen also start a new transaction where a Scheduled Path does not fit. For very large data volumes, prefer a Schedule-Triggered Flow or asynchronous Apex over synchronous in-transaction processing.

**2.5 Invocable Apex must be bulk-safe.** Any Apex called from a Flow (Invocable/Apex Action) must accept and return Lists (collections) so it is bulkified. Do not use legacy Process.Plugin Apex actions — they run once per interview and break bulkification. This is the correct pattern for offloading heavy computation to Apex.

**2.6 No split DML paths in subflows.** Subflows must not perform DML on records the parent also writes. Return modified records to the parent and let the parent run one consolidated bulk update, so the same record is not written by multiple independent DML paths in one transaction.

**2.7 Scan in CI.** Run the Lightning Flow Scanner against every Flow in the build and fail on "DML Statement In A Loop," "SOQL Query In A Loop," and "Same Record Field Updates" (same-record after-save update) violations, so bulkification is enforced mechanically rather than by reviewer memory.

## §3 Fault Handling & Logging

**3.1 Fault path on every fallible element.** Every element that can throw — Create/Update/Delete Records, Get Records, and Action/Apex/callout/subflow elements — must have a Fault path attached, even when failure seems impossible.

**3.2 Guard empty Get results.** A Get Records followed by logic that assumes a record was returned must route through a Fault path or an explicit null/empty check; downstream assignments and DML fail when the Get returns nothing.

**3.3 Never leave a fault path empty or silent.** A Fault path must lead to explicit handling — log, notify, and/or a controlled stop. It must never be an empty connector or a jump back onto the happy path that swallows the error. Silent fault paths hide broken data until a user reports it.

**3.4 Log durably to an exception sink.** Fault paths must write to a durable log so failures are visible without waiting for a user to report them. **If the org already has an exception-logging object, log there** (map at minimum the fields below onto it). **If the org has no such object, do not swallow the error** — recommend and establish one, and until it exists route the error to the most durable channel available (a platform event, or at minimum a notification to the automation owner). The recommended pattern to establish is: domain platform events named `<Domain>_Exception__e`, defined **Publish Immediately**, whose subscriber persists to a custom logging object such as `Exception_Log__c`. Log at minimum the automation name, `{!$Flow.FaultMessage}`, and the triggering record Id. Because a `<Domain>_Exception__e` event publishes independently of the triggering transaction, the log survives even when a record-triggered transaction rolls back — a direct DML insert of a log record would be lost in that rollback. Publish the platform event on the fault path; the subscriber writes the durable log row for reporting.

**3.5 Centralize the fault logic.** Error handling should be implemented once in a shared reusable autolaunched Flow (taking record Id and fault message as inputs, publishing the `<Domain>_Exception__e` event) and invoked from every fault path, rather than rebuilt inline in each Flow. Because before-save and platform-event-triggered Flows cannot call a subflow, in those contexts publish the event or call Apex directly.

**3.6 Surface a modern, high-visibility error in screen flows.** In interactive flows, the Fault path must show a Screen with a readable, actionable message plus `{!$Flow.FaultMessage}` and the relevant record context — never the raw unhandled-fault screen, and never raw platform exception text. Prioritize a **modern presentation with high readability and visibility**: a clear headline stating what went wrong, the specific next action the user can take, and the error detail visually separated in its own section rather than buried in a paragraph. Use the screen's rich-text formatting — heading, bold labels, spacing — for clear visual hierarchy, or a dedicated error LWC where richer styling, iconography, or colour further improves visibility. The bar is that a non-technical user immediately understands what failed and what to do next.

Recommended implementation, in order of preference:
- **Dedicated error LWC (preferred for high visibility).** Wrap the message in the SLDS error pattern — e.g. `slds-scoped-notification slds-theme_error` (or an inline `slds-notify slds-notify_alert slds-theme_error`) with a `utility:error` icon, a bold headline, the actionable next step, and `{!$Flow.FaultMessage}` in a de-emphasized detail block. Use SLDS design tokens for colour so it stays theme- and accessibility-consistent, and set the appropriate ARIA role (`role="alert"`) so assistive tech announces it.
- **Rich-text Display Text (no-code fallback).** When a component is overkill, format the Display Text element itself: a coloured/bold `⚠` headline line, a normal-weight next-action line, then the fault detail in a visually separate block (e.g. a quote/callout style). Keep the raw fault text visually secondary to the human-readable guidance.

Include the record context (name/Id and the step that failed) so the user can report it precisely, and always pair the friendly screen with the durable log from §3.4 — the screen informs the user, the log informs the team.

**3.7 Decide block vs log-and-continue deliberately.** For each fault path, consciously choose whether to halt the transaction (custom error message / blocking) or log-and-continue. A custom error message blocks and rolls back the triggering DML; a fault connector to any other element lets the triggering DML commit. Match this choice to business intent — an unconsidered choice causes silent partial commits.

**3.8 Prevention still required.** Fault paths are a safety net, not a substitute for prevention. Still enforce required-field/validation checks, null guards, and bulk-safe design. Frequent traversal of a fault path is a defect signal — redesign the automation rather than treating the fault path as steady state.

## §4 PR / Deployment Compliance Checklist

Tick every item before requesting review or deploying. Items marked (owned) apply only to team-owned Flows; managed-package Flows are exempt.

- [ ] Flow is in **Auto-Layout** (not Free-Form).
- [ ] Flow is saved at the **latest Flow API version** available in the org (no API 0, none left below the current default).
- [ ] **Version Description present** — single-line `YYYY-MM-DD: summary`, no ticket IDs.
- [ ] Naming convention followed: object-prefixed Flow name; noun Resources / verb Elements; Decisions as questions with prefixed Outcome answers; Loops `Each_<Record>`.
- [ ] **No hardcoded record Ids or RecordType Ids** — resolved via Get by DeveloperName or Custom Metadata.
- [ ] **One orchestrator Flow per object per context** — record-triggered logic routed through a single before-save and a single after-save entry point per object (subflow-delegated), not multiple competing record-triggered Flows. (owned)
- [ ] No InvalidDraft or stray Draft shipped; **Obsolete/InvalidDraft versions cleaned up** (Active + at most ~2 recent inactive retained). (owned)
- [ ] **No Get/Create/Update/Delete inside any Loop**; collection-then-single-DML pattern used.
- [ ] Bulk-tested at ~200 records; no approach to the 100 SOQL / 150 DML / 50k row / 10k DML-row limits.
- [ ] Non-real-time heavy work offloaded — **Scheduled Path by default** (or async Apex / new transaction); only logic the user must see immediately stays synchronous.
- [ ] Invocable Apex accepts and returns **Lists**; no Process.Plugin actions.
- [ ] **Lightning Flow Scanner passed** (no DML-in-loop or SOQL-in-loop violations).
- [ ] **Fault path on every** DML, Get, and Action/Apex/callout element; none empty or silent.
- [ ] Faults **logged durably** to an exception sink (automation name, `{!$Flow.FaultMessage}`, record Id) — if the org has no logging object, one is recommended/established, never swallowed.
- [ ] Block-vs-log-and-continue decision made deliberately per fault path.
- [ ] Screen-flow fault paths show a **modern, high-visibility** error (clear headline + specific next action + separated detail), never raw.
