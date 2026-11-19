# HTTP and lifecycle findings

Consult the [CoilBase getting-started guide](https://github.com/PVRLabs/coilbase/blob/main/docs/getting-started.md) and [database configuration](https://github.com/PVRLabs/coilbase/blob/main/docs/database-configuration.md) for the target version. Both the JPA PetClinic port and the JDBC Task Tracker port used explicit constructors and generated Avaje route adapters. The examples below help diagnose differences when HTTP is part of the migration contract.

## Server-rendered workflows

PetClinic kept recognizable controller, service and repository responsibilities, with separate form inputs and precompiled JTE. Its shared packaged contract covered representative search, edit, visit, validation, redirects, navigation and static assets. It also checked selected security properties. The local bounded sessions were process-local and lost on restart, with narrower locale coverage and different flash behavior from Spring. These tradeoffs need review against the deployment's requirements. [PetClinic contract](https://github.com/ejboy/coilbase-petclinic/tree/main/contract)

- If forms are in scope, compare rejected values, parsing and localized errors, ownership and CSRF, redirects, and persistence. Include encoded spaces, literal plus and Unicode. Derive write targets from trusted route and authorization decisions, and enforce ownership at the persistence boundary.
- In the tested stack, generated POST routes defaulted to 201, so invalid form responses explicitly selected 200. Jex 3.6 preserved form `+`; PetClinic used bounded application-local decoding and rejected malformed encodings. Static opt-in required a packaged classpath index even with a root controller. Inspect current behavior before reusing these fixes.

## API contracts

Task Tracker was a JDBC/H2 migration. Its eleven packaged error comparisons and restart check verify techniques that also apply to JPA migrations. Where clients require parity, check malformed bodies and IDs, unsupported methods and media types, trailing-slash policy and expected error fields. In the tested Avaje/Jex stack, the generated adapter wrapped invalid path values in `InvalidPathArgumentException`. Jex 3.6 strict-slash configuration truncated a captured path argument in the tested route, so Task Tracker kept default parameter matching and used a small before-handler to reject slash aliases. Prefer the current documented option if it passes the contract. For Problem Details on Jex 3.6, select status and media type and write the serialized body explicitly because `ctx.json()` commits JSON headers. [CoilBase HTTP migration guide](https://github.com/PVRLabs/coilbase/blob/main/docs/spring-boot-migration.md#exception-handling-and-problem-details)

## Packaged lifecycle

Use the framework's datasource and lifecycle facilities where they satisfy the contract. For example, the Jex base owns shutdown of a closeable datasource returned from its primary datasource hook. Account for failure before ownership transfers, and for resources created outside that hook. Preserve configuration and driver/database options that actually affect behavior. Verify readiness using the database and any required initialized state. Check scheduler termination, persisted restart without reseeding when required, and independent database state. Task Tracker reopened the Spring-created H2 file; PetClinic used independently initialized matching fixtures for each app and then restarted each app against its own persisted state.
