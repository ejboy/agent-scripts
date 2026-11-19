---
name: coilbase-jpa-migration
description: Assess or migrate JPA, Spring Data JPA, and Hibernate workflows to CoilBase/Jdbi, with Spring Boot and Spring MVC optionally retained. Also covers retaining Hibernate as an explicit migration choice.
---

# Migrate JPA and Hibernate workflows to CoilBase

## Establish the slice and contract

Read the [CoilBase migration guide](https://github.com/PVRLabs/coilbase/blob/main/docs/spring-boot-migration.md) for the JDBC and lifecycle foundation. Check the target versions against the guide and consult version-matched API sources when details differ. The case studies in [persistence patterns](references/persistence-patterns.md) use Preview 4 and show application choices. For a persistence-only migration that keeps Spring Boot, see [retained Spring wiring](references/retained-spring.md).

Trace one business operation from its route, batch job or scheduler through actual callers to committed state. Locate Spring Data queries, flush-driven writes, cascades and ownership, lazy reads, ordering, identity generation, callbacks, caches, and transaction entry points that the operation uses. Check the actual schema and initialization policy, required database dialects and any existing-data compatibility requirement. Capture the baseline behavior before changing it, with separate disposable data for comparison. Mark what is observed, source-derived or still unknown.

Choose explicit SQL or retained Hibernate for the slice. Replacing ORM persistence while keeping Spring Boot and Spring MVC can be the final scope or the first phase of a broader migration. If the user also wants to move off Spring Boot, verify the persistence slice first and reuse it in the infrastructure phase. The optional `coilbase-spring-migration` skill covers that phase. Choose HTTP, rendering and deployment changes according to the requested scope. Preserve business behavior, data integrity and required security guarantees. Record deliberate differences and resolve application decisions that materially affect the contract.

The [combined PetClinic trial](https://github.com/PVRLabs/experiments/tree/main/java/coilbase/petclinic-combined) migrated all three PetClinic JPA repositories to CoilBase/Jdbi while retaining Spring Boot and Spring MVC. Verification covered H2, with caller-supplied repository sorting outside the accepted scope. Read its README first, then fetch only the files needed for the task. A checkout of the experiments repository is unnecessary.

## Implement with existing facilities

- Keep the application's recognizable service and repository boundaries and use explicit constructor wiring. Use CoilBase's shared `RepositoryContext`, `SqlStatement` and Jdbi callbacks for SQL. Make row mapping, generated keys, field updates, relationship reads and related writes explicit. See [persistence patterns](references/persistence-patterns.md) for loading, ownership, constraints and Hibernate retention.
- Give the business operation a transaction owner. Participating SQL calls normally share one context and thread. Inspect outer callers, propagation, flush timing, isolation and rollback rules. Preserve lock lifetime through the owning commit. Check retries and external side effects at the same boundary.
- Use the selected integration's existing startup and cleanup hooks. Determine who owns the datasource, schema, scheduler and, when retained, Hibernate sessions and the session factory. Read [HTTP and lifecycle findings](references/http-and-lifecycle.md) when moving Spring web or operational behavior, or when generated adapters diverge from the baseline. For framework alternatives, see the [CoilBase integration guide](https://github.com/PVRLabs/coilbase/blob/main/docs/framework-integrations.md).

## Verify the migration

Run representative baseline and port journeys through their normal entry points. Compare required response behavior and independently query the committed rows, including the absence of invalid writes. Inject a failure after an earlier write and check rollback and later recovery. Exercise competing writes, stale versions, lock lifetime or outer calls when the slice depends on them. A mock context can test wiring or branching; transaction and constraint acceptance requires real SQL.

Repeat database-specific checks for each claimed backend. When packaging or lifecycle changes, verify readiness against the required resources, graceful cleanup and packaged restart with persisted state. If existing data must survive the change, verify the port against a disposable copy made by the source application. Report commands and results, decisions and accepted differences, plus any unverified requirements.
