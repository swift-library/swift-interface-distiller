# Integration proposals

These integrations are proposals, not shipped entry points.

- **MCP server:** expose snapshot queries as a transport adapter over the library.
- **SwiftPM command plugin:** invoke collection using an explicit package context
  and permission request, leaving snapshot semantics in the library.
- **Index adapter:** usage relationships, used dependency symbols and source-file
  slices belong to the upper layer provided by distiller-ultra. The snapshot
  model supplies declarations and configuration identities to that layer.
- **Macro expansion fixtures:** compare explicitly compiled expansion scenarios;
  declaration evidence alone does not establish generated API behavior.
- **SDK catalog jobs:** provide separately configured SDK collection jobs with
  recorded toolchain and license context, using ordinary snapshot merging.
- **Remote package fetching:** add an explicit acquisition layer that resolves a
  version before collection. Current extraction takes local inputs.
- **llms.txt:** publish a navigation artifact from accepted documentation without
  adding policy or interpretation to the snapshot model.
