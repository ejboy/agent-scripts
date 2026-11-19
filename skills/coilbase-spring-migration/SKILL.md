---
name: coilbase-spring-migration
description: Migrate Spring Boot JDBC workflows directly to CoilBase, or move Spring Boot infrastructure after a workflow already uses CoilBase/Jdbi. Avaje Jex is the default HTTP stack. For workflows that still depend on JPA or Hibernate, assess persistence first.
---

# Spring Boot to CoilBase migration

This experimental skill is maintained in Agent Scripts, outside the CoilBase repositories. Work within the user's migration scope, preserving the existing application as an independent baseline.

## Establish the reference and contract

Read the [published CoilBase migration guide](https://github.com/PVRLabs/coilbase/blob/main/docs/spring-boot-migration.md) before proposing API usage. It is the technical authority. A matching local checkout can supply the guide and API sources; record its revision and any differences from the published reference. Check the target dependency versions: the guide uses Preview 4 and discusses Jex 3.6 behavior. Do not silently upgrade the application or invent replacement APIs when versions differ.

Inventory routes, response fields and media types, validation, configuration, SQL, schema initialization, background work and lifecycle. Trace actual transaction entrypoints and callers rather than replacing annotations mechanically. Capture existing behavior checks before editing; distinguish source-derived expectations from executed observations.

Migration does not promise one-to-one Spring Boot compatibility. Preserve essential application correctness, business behavior, data integrity, transaction semantics and required security guarantees. Treat framework conveniences and incidental HTTP behavior as explicit application decisions; allow deliberate, documented simplifications when their tradeoffs meet the user's requirements. Prefer idiomatic CoilBase APIs and application architecture over compatibility workarounds with little practical value. Do not silently change externally required behavior or assume compatibility differences are harmless. Jex is the practical default here; CoilBase is not tied to that HTTP stack.

For each affected feature, record: source location and behavior; carry over, adapt, or explicit design required; guide section supporting the mapping; proposed application change; acceptance check and unresolved questions. Preserve controller, service and repository responsibilities where useful.

## Apply documented mappings

Before adding custom workarounds or parallel application infrastructure, inspect the target version's documentation and API sources and prefer existing CoilBase lifecycle hooks, extension points and repository patterns where they meet the migration contract.

Use the guide sections on wiring, JDBC, transactions, exceptions, configuration and static resources as needed:

- Carry over ordinary models, calculations, validation and SQL where dependencies permit. Adapt constructor wiring, HTTP registration, bindings and row mapping explicitly.
- Choose the business operation's transaction owner. Fetch external data and validate before a short transaction where the contract permits. Keep participating calls on the same `RepositoryContext` and thread; separate contexts from the same datasource do not imply shared transactions. Review propagation, isolation, read-only hints and rollback rules individually. Direct batch callers need an explicit boundary if repositories only participate.
- Preserve locks through the outer commit, timestamps, decimals, constraints and ordering. Verify supported database dialects separately.
- Map business errors explicitly, including media type. For the guide's Jex 3.6 Problem Details pattern, serialize and write after selecting status and content type; `ctx.json()` chooses `application/json` and commits headers. Check malformed requests separately.
- Preserve deployment environment names, defaults and initialization policy. Define database-backed readiness, background startup, shutdown and failed-start cleanup. Enable static serving only where required and test the packaged assets.

## Resolve features beyond the guide's JDBC mappings

Check the affected workflow for Spring Data JPA repositories, mapped entities or direct `EntityManager` or Hibernate `Session` calls. Verify actual usage in mixed applications. If the goal is to move off both the ORM and Spring Boot, migrate and verify persistence first. The optional `coilbase-jpa-migration` skill covers that phase. Then reuse the CoilBase/Jdbi layer while adapting HTTP, configuration, wiring and lifecycle.

Spring Data/JPA, entity management, security, Actuator, scheduling annotations and full Spring property/transaction semantics have no established automatic conversion here. Identify the decisions and required evidence before implementing them. Do not introduce a migration framework or transformation engine, or change CoilBase APIs to fit the migration.

For JPA relationships, explicitly decide loading queries and ordering, generated IDs, ownership, write order, cascade replacements, constraints, query count and caching. Multi-query reads alone do not prove snapshot consistency. For server-rendered applications, inventory rendering, form decoding/binding, field errors, redirects, sessions/CSRF, localization and static assets. Resolve only what the requested slice requires; leave unanswered design questions visible.

The [PetClinic migration](https://github.com/ejboy/coilbase-petclinic/blob/main/docs/migration.md) is supporting evidence for these decisions, not a required architecture or an automatic JPA/Thymeleaf recipe. Consult its relevant implementation and contract when using an example. Label application-local workarounds and accepted differences; do not generalize its renderer, session design or SQL loading strategy into CoilBase requirements.

The [combined PetClinic trial](https://github.com/PVRLabs/experiments/tree/main/java/coilbase/petclinic-combined) then removed Spring Boot and Spring MVC, using Avaje Jex with the same CoilBase/Jdbi repository files. Verification covered H2, with caller-supplied repository sorting outside the accepted scope. The trial documents its rendering, flash-message, and health endpoint choices. Read its README first, then fetch only the files needed for the task. A checkout of the experiments repository is unnecessary.

## Verify and report

Use independent disposable data for original and migrated applications. Compare HTTP success and errors (including media types), committed rows and invalid-write rejection. Force failure after an earlier write, verify rollback and subsequent recovery; exercise outer transactions and competing edits where relevant. Check initialization, database readiness, shutdown, packaged restart and persistence. Repeat database-specific checks for every claimed backend.

Report changed files and decisions, commands actually run and outcomes, inherited evidence, unsupported patterns, errors and manual corrections, additional knowledge needed beyond the guide, and remaining acceptance gaps. Distinguish functional equivalence from deliberate differences and untested behavior. A passing JDBC example does not validate JPA relationships or presentation. Stop equivalence claims at the tested scope; publication is a separate decision.
