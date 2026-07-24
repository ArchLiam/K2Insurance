# Lightning Web Components (LWC) Coding Compliance Standard

## §0 Purpose & Scope

This standard defines the mandatory engineering rules for building and maintaining Lightning Web Components in this org. LWC is the client-side layer users actually touch; undisciplined component design produces slow pages, security holes (XSS, FLS bypass), un-testable spaghetti, and UI that silently diverges from the data model. These rules exist so any reviewer can read, reason about, and safely deploy a component regardless of who authored it, and so the front end stays consistent with the [Apex Compliance Standard](apex-compliance.md) it calls into.

**Applies to:** all in-house LWCs owned by this team — UI components, Flow screen components, utility/service components, and their Apex controllers, Jest tests, and `-meta.xml`.

**Exempt:** third-party managed-package components (namespaced, e.g. `pse__`) and Salesforce base components (`lightning-*`, `lightning/*` modules) are consumed, not modified, and are outside these rules. Aura components are out of scope — new work is LWC; Aura is used only as an unavoidable wrapper where LWC lacks a capability.

"Must" denotes a hard requirement enforced at code review and deployment. "Should" denotes a strong default that requires a documented reason to deviate. Where server-side behavior is implicated (Apex controllers, sharing, CRUD/FLS, error logging), the Apex Compliance Standard governs and is referenced rather than duplicated.

## §1 Bundle Structure, Naming & Metadata

**1.1 Canonical bundle layout.** A component folder name is **camelCase** and every file in the bundle shares that base name (`myComponent.js`, `myComponent.html`, `myComponent.css`, `myComponent.js-meta.xml`). The JS module's default-exported class is **PascalCase** (`export default class MyComponent extends LightningElement`). In markup a component is referenced in **kebab-case** with the `c-` namespace (`<c-my-component>`).

**1.2 Latest API version is mandatory.** Every `*.js-meta.xml` must declare the current API version available in the org — never left pinned to an old release. State this as evergreen ("latest available"), not a fixed number; bring stale bundles current as part of any edit.

**1.3 Metadata is explicit and intentional.** `isExposed`, `targets`, and `targetConfigs` must reflect exactly where the component is meant to run — never expose a component to surfaces it was not designed and tested for. Design-time properties for App Builder/Flow go in `targetConfigs` with `label` and `description`; declare `objects` and `supportedFormFactors` where relevant.

**1.4 One responsibility per bundle.** A component does one job. Split a component that has grown to mix data-fetching, layout, and business rules (see §2). Bundle only what the component needs; shared logic goes in an ES module under a `utils`/service bundle and is imported, not copy-pasted.

## §2 Component Design & Composition

**2.1 Container vs. presentation split.** Prefer separating **container (smart) components** that fetch data and own state from **presentation (dumb) components** that receive data via `@api` and emit events. This keeps presentation components pure, reusable, and trivially testable.

**2.2 Public API is deliberate and typed.** A component's public surface is only its `@api` properties and `@api` methods. Keep it minimal and named for intent. Public property names are camelCase in JS and kebab-case in markup (`recordId` ↔ `record-id`). `recordId` and `objectApiName` must use those exact standard names when the component runs on a record page.

**2.3 One-way data flow — never mutate `@api` props.** Treat every `@api` property as read-only owned by the parent. A child requests change by dispatching an event; it must not write back into its `@api` inputs (§8). Mutating a passed-in object/array reaches into the parent's state and is prohibited.

**2.4 Compose over reach-in.** Parents pass data down through props and slots; children communicate up through events. A component must not query into another component's shadow DOM, call undocumented internals, or depend on a sibling's markup. Use `<slot>` for content projection.

**2.5 Modern template directives.** Use `lwc:if` / `lwc:elseif` / `lwc:else` for conditional rendering (not the deprecated `if:true`/`if:false`). Every `for:each` and `iterator:` **must** have a stable, data-derived `key` (never the array index) so the diffing engine reconciles correctly.

**2.6 Lifecycle discipline.** Do not do heavy work or fire events in `constructor` (the element isn't in the DOM yet, `@api` values aren't set). Access DOM only from `renderedCallback` and guard it against re-entrancy (it runs on every render). Always remove listeners/timers added in `connectedCallback` in `disconnectedCallback`.

## §3 Reactivity & State

**3.1 Fields are already reactive — `@track` is the exception.** Since the field-reactivity change, reassigning a field (including a whole object or array) re-renders automatically. Use `@track` **only** to observe **mutations of the contents** of an object or array held in a field. Prefer immutable updates (`this.rows = [...this.rows, newRow]`) over in-place mutation, which removes the need for `@track` and avoids subtle bugs.

**3.2 Getters, not expressions, for derived values.** LWC templates support property access only — no function calls or computed expressions. Compute derived/display values in a **getter** (e.g. `get isDisabled()`), keep getters cheap and side-effect-free, and never trigger a re-render or fire a request from a getter.

**3.3 No business logic in the template or the getter layer.** Keep decisions in named methods/getters with intention-revealing names; the template stays declarative.

## §4 Data Access — Lightning Data Service First

**4.1 Prefer LDS over Apex for record CRUD.** For single-record read/create/update/delete, use Lightning Data Service before writing an Apex controller: base components `lightning-record-form` / `lightning-record-view-form` / `lightning-record-edit-form`, or the wire adapters and functions from `lightning/uiRecordApi` (`getRecord`, `getRecords`, `getFieldValue`, `createRecord`, `updateRecord`, `deleteRecord`) and `lightning/uiObjectInfoApi` (`getObjectInfo`, `getPicklistValues`). LDS caches, keeps every component on the page in sync, and **enforces FLS and sharing automatically** — no server code to maintain or secure.

**4.2 Reference schema, never string literals.** Import objects and fields via `@salesforce/schema/Object.Field`. This gives referential integrity — a deleted/renamed field breaks at deploy time, not at runtime.

**4.3 `@wire` before imperative.** Prefer reactive `@wire` for reads so data refreshes when reactive parameters change and participates in the LDS cache. Use imperative calls only when you must control timing (on user action) or sequence multiple calls. A `@wire` target must never perform side effects beyond assigning the received data/error.

**4.4 Refresh via the framework.** To re-fetch wired data after a mutation, use `refreshApex` (for wired Apex) or let LDS update the cache (for `uiRecordApi` writes). Never re-render by mutating cached wire results in place.

## §5 Apex Interop

**5.1 Cacheable reads, imperative writes.** Read-only Apex exposed to LWC **must** be `@AuraEnabled(cacheable=true)` (enables the client cache and `@wire`) and **must not** perform DML. Any method that writes is imperative `@AuraEnabled` (no `cacheable`) and is called from an event handler, never from `@wire`.

**5.2 The controller is a thin adapter — logic lives in a Service.** Per [Apex Compliance §4](apex-compliance.md), an `@AuraEnabled` controller only adapts the request to a `*Service`; it holds no business logic and is not reused as a service.

**5.3 Security is enforced server-side.** LDS enforces FLS/sharing for you; **custom Apex does not by default.** Every Apex controller backing an LWC **must** declare `with sharing` and enforce CRUD/FLS ([Apex Compliance §6](apex-compliance.md)) — `WITH USER_MODE` (or `WITH SECURITY_ENFORCED`) on SOQL, `Security.stripInaccessible` / `Schema` accessibility checks on writes. A `cacheable=true` method still needs FLS enforcement — caching is not authorization.

**5.4 Bulk-safe and selective.** Controllers accept and return collections and obey the same bulkification/selectivity rules as all Apex ([Apex Compliance §5](apex-compliance.md)); no SOQL/DML in loops, no hardcoded Ids.

**5.5 Errors surface, never leak.** Imperative controller failures throw `AuraHandledException` with a controlled, user-friendly message ([Apex Compliance §9](apex-compliance.md)); the raw system exception is logged server-side through the `<Domain>_Exception__e` telemetry pipeline, never returned to the browser.

## §6 Security (Lightning Web Security)

**6.1 No unsafe DOM injection.** Never assign untrusted data to `innerHTML`, and avoid `lwc:dom="manual"` unless a base component genuinely cannot do the job; when unavoidable, render only sanitized content. No `eval`, no `document.write`, no dynamically-built script/style injection.

**6.2 No secrets or Ids in client code.** Never hardcode credentials, tokens, session Ids, or record/RecordType Ids in JS/HTML — the browser bundle is fully inspectable. Resolve Ids at runtime (LDS, `getObjectInfo`, Custom Metadata via Apex).

**6.3 Trust the platform sandbox, don't defeat it.** Code must run under **Lightning Web Security** without disabling protections. No global-scope leakage, no reaching across namespaces, no cross-origin calls except through approved channels (Named Credentials/Apex, CSP Trusted Sites). External resources load only via Static Resources or an allow-listed CSP Trusted Site.

**6.4 Escape and validate at the boundary.** Treat all user- and URL-supplied input as untrusted; validate/normalize before use and before passing to Apex. Server-side remains the authoritative validation layer.

## §7 Performance

**7.1 Cache and lazy-load.** Use `cacheable=true`/LDS caching for reads. Defer expensive or below-the-fold work with `lwc:if` and dynamic `import()`; don't instantiate what the user hasn't asked for.

**7.2 Cheap templates.** Keep getters O(1)-ish and free of I/O; move heavy computation out of the render path. Avoid re-computing large derived collections on every render.

**7.3 Debounce and batch.** Debounce keystroke-driven search/filter handlers before hitting Apex; batch related reads into a single controller call rather than many small wires.

**7.4 Right tool for volume.** Use `lightning-datatable` with server-side pagination/`enableInfiniteLoading` for large lists; never render thousands of DOM rows. Paginate and filter server-side.

**7.5 Minimize re-render churn.** Prefer immutable reassignment over deep mutation, key iterators correctly (§2.5), and avoid wiring on parameters that change more often than the data needs to.

## §8 Events & Cross-Component Communication

**8.1 Child→parent via CustomEvent.** Children communicate up by dispatching a `CustomEvent`. Event names **must** be lowercase, no spaces, no hyphens-in-name (`recordselected`, not `recordSelected` or `record-selected`); pass data in `detail`. Default to **not** `bubbles`/`composed`; enable them only with a clear reason (they cross shadow boundaries and couple components).

**8.2 Parent→child via props/methods.** Parents push data down through `@api` properties or call `@api` methods on a queried child — never by mutating child internals.

**8.3 Cross-DOM via Lightning Message Service.** For sibling or cross-hierarchy communication (components in different regions/DOM trees), use **Lightning Message Service** (`lightning/messageService` + a Message Channel). The old `pubsub` pattern is a legacy workaround and must not be introduced in new code.

**8.4 `detail` payloads are serializable and defensive.** Don't pass live object references a listener could mutate across the boundary; pass plain data. Handlers must tolerate missing/partial `detail`.

## §9 Styling & Accessibility

**9.1 Base components first, SLDS second, custom CSS last.** Build UI from `lightning-*` base components, which are accessible and theme-consistent by default. Use SLDS utility classes for layout. Write custom CSS only for what SLDS/base components can't express.

**9.2 Theme via SLDS styling hooks — no hardcoded colors.** Use SLDS styling hooks / CSS custom properties (`--slds-*` / `--sds-*`) rather than literal hex/rgb values, so components respect theming, density, and dark mode. Component CSS is scoped; use `:host` for the element itself and don't override SLDS internal class implementations.

**9.3 Accessibility is mandatory, not optional.** Every interactive element has an accessible name (`label`, `alternative-text`, `aria-*` as needed); color is never the only signal; components are fully keyboard-operable with a sensible focus order and managed focus for dialogs/menus. Prefer base components' built-in a11y over hand-rolled markup.

## §10 Internationalization & Labels

**10.1 No hardcoded user-facing strings.** All display text comes from **Custom Labels** imported via `@salesforce/label/c.My_Label`. This keeps copy translatable and centrally editable.

**10.2 Locale-aware formatting.** Format dates, numbers, and currency with `lightning-formatted-date-time` / `-number` / `-currency` (or the `@salesforce/i18n/*` modules), never with manual string concatenation, so output respects the user's locale and the org's multi-currency settings.

## §11 Error Handling in the UI

**11.1 Handle both wire and imperative errors.** A `@wire` must destructure and handle `{ data, error }`; an imperative call must `try/catch` (or `.catch`). An unhandled `error` branch is a violation.

**11.2 Normalize errors before display.** Use a shared `reduceErrors(errors)` utility (the lwc-recipes pattern) to flatten Apex/LDS/JS error shapes into readable messages. Surface them with `lightning/platformShowToastEvent` or an inline SLDS error region — never a blank screen or a raw stack trace.

**11.3 Never swallow.** A caught client error is shown to the user and/or reported; an empty `.catch` is prohibited. Server-side logging remains the Apex telemetry pipeline's job ([Apex Compliance §9](apex-compliance.md)).

## §12 Testing (Jest / sfdx-lwc-jest)

**12.1 Every bundle has a Jest test.** Tests live in `__tests__/` and run under `@salesforce/sfdx-lwc-jest`. A component without tests does not merge.

**12.2 Mock the wires and Apex.** Wire adapters and imported Apex methods **must** be mocked (test wire adapters / `jest.mock`); tests never hit a real org. Emit both data and error cases through the mock and assert the rendered result.

**12.3 Assert real behavior.** Assert on rendered DOM, dispatched events, and public API — not framework internals. Cover positive, negative, empty-data, and error branches. Await `Promise.resolve()` (microtask) before asserting post-render DOM.

**12.4 One test bundle per component**, named for the component; no snapshot-only tests standing in for behavioral assertions.

## §13 Documentation

**13.1 JSDoc header on the class and public members.** Every component class opens with a JSDoc block containing a one-line `@description` and the `@author Liam Jeong <liam.jeong@5sinfusion.com>` line (verbatim, matching the Apex standard). Every `@api` property and `@api` method carries a short JSDoc describing its contract. **No** ticket numbers, dates, or changelogs in source — that history lives in git ([Apex Compliance §1](apex-compliance.md)).

### JSDoc header template (copy-paste)

```js
/**
 * @description One line stating what this component does.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */
import { LightningElement, api } from 'lwc';

export default class ExampleComponent extends LightningElement {
    /** @description The record whose details are displayed. */
    @api recordId;
}
```

## §14 PR / Deployment Compliance Checklist

Tick every item before requesting review or deploying.

- [ ] Bundle layout correct: **camelCase** folder/files, PascalCase class, `c-kebab-case` in markup.
- [ ] `-meta.xml` at the **latest API version**; `isExposed`/`targets`/`targetConfigs` match intended surfaces only.
- [ ] Single responsibility; container/presentation split where the component both fetches and renders.
- [ ] Minimal `@api` surface; **`@api` props never mutated**; child→parent via events only.
- [ ] `lwc:if`/`elseif`/`else` used; every `for:each`/`iterator` has a stable non-index **`key`**.
- [ ] No template expressions/function calls — derived values in cheap, side-effect-free **getters**.
- [ ] `@track` only for deep object/array mutation; immutable reassignment preferred.
- [ ] **LDS/`@wire` used before custom Apex**; fields/objects imported via `@salesforce/schema`.
- [ ] Read Apex is `@AuraEnabled(cacheable=true)` with **no DML**; writes are imperative.
- [ ] Apex controllers `with sharing`, **CRUD/FLS enforced** (`WITH USER_MODE`/`stripInaccessible`), thin adapter to a Service, bulk-safe, no hardcoded Ids. ([Apex §4–§6](apex-compliance.md))
- [ ] No `innerHTML`/`eval`/unsafe `lwc:dom="manual"`; no secrets or Ids in client code; runs clean under Lightning Web Security.
- [ ] Performance: caching/lazy-load, debounced search, server-side pagination for large lists, keyed iterators.
- [ ] Event names lowercase/no-space; `bubbles`/`composed` only with reason; **LMS** (not pubsub) for cross-DOM.
- [ ] Base components + SLDS; **styling hooks, no hardcoded colors**; scoped CSS; full a11y (labels, keyboard, focus).
- [ ] User-facing text via **Custom Labels**; dates/numbers/currency via `lightning-formatted-*`.
- [ ] Both `@wire` and imperative **errors handled**; normalized via `reduceErrors`; shown via toast/inline; never swallowed.
- [ ] **Jest tests present**, wires/Apex mocked, positive/negative/empty/error branches asserted on real DOM/events.
- [ ] JSDoc header with `@description` + `@author Liam Jeong <liam.jeong@5sinfusion.com>`; `@api` members documented; no tickets/dates in source.
