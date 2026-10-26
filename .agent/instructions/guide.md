---
description: Route swift-interface-distiller changes through its contracts and keep snapshots complete and canonical.
---
# Interface Distiller Agent Guide

## Task Route

- Read `Documentation/Contracts.md` before changing behavior.

## Repository Guardrails

- The library owns snapshots, collection, queries, rendering and comparison;
  the executable owns argument handling and streams.
- Preserve compiler identifiers and distinguish missing observations from
  negative facts. Every derived fact needs a documented derivation.
- A snapshot format change needs a schema compatibility review and fixture
  tests.
- Never substitute a partial result for a complete baseline. Keep execution
  paths, timing and cache state in run reports, outside canonical snapshots.
