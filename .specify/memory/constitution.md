<!--
SYNC IMPACT REPORT
==================
Version change: [TEMPLATE] → 1.0.0 (initial ratification; all placeholders replaced)

Modified principles:
- [PRINCIPLE_1_NAME] → I. Plugin Isolation (NON-NEGOTIABLE)
- [PRINCIPLE_2_NAME] → II. DI-First Service Architecture
- [PRINCIPLE_3_NAME] → III. Graceful Lifecycle Management
- [PRINCIPLE_4_NAME] → IV. Test-Driven Quality
- [PRINCIPLE_5_NAME] → V. Semantic Versioning & Multi-Target Compatibility

Added sections:
- Technical Constraints (formerly [SECTION_2_NAME])
- Development Workflow (formerly [SECTION_3_NAME])

Removed sections: none

Templates reviewed:
- .specify/templates/plan-template.md   ✅ aligned (Constitution Check gate present)
- .specify/templates/spec-template.md   ✅ aligned (no mandatory sections conflict)
- .specify/templates/tasks-template.md  ✅ aligned (lifecycle/testing task types match)
- .claude/commands/*.md                 ✅ reviewed; no agent-specific name conflicts

Deferred TODOs: none
-->

# Juice.Plugins Constitution

## Core Principles

### I. Plugin Isolation (NON-NEGOTIABLE)

Each plugin MUST be loaded into its own `AssemblyLoadContext` (isCollectible: true) to prevent
type identity conflicts between plugins and the host process.

- Plugins MUST NOT share concrete type definitions directly; shared contracts MUST be
  expressed through a dedicated shared-base assembly (e.g., `PluginBase`) referenced by
  both host and plugin.
- A plugin's `AssemblyLoadContext` MUST be fully unloadable at runtime without restarting
  the host application.
- Type resolution MUST fall back to the default context only for types not resolvable
  within the plugin's own resolver (`AssemblyDependencyResolver`).
- Unmanaged library paths MUST be resolved via the plugin's own dependency resolver
  before falling back to the system.

**Rationale**: Without isolation, version conflicts between plugins (or between a plugin and
the host) cause unpredictable runtime failures. Collectible contexts enable hot-reload
without process restarts.

### II. DI-First Service Architecture

Every plugin MUST register its services through Microsoft.Extensions.DependencyInjection.
No service MUST be accessed by direct instantiation within a plugin boundary.

- Each plugin MUST expose a `Startup` class with a
  `ConfigureServices(IServiceCollection, IConfiguration)` method. The absence of this
  method means the plugin is treated as non-initialized (`IsInitialized = false`).
- The host MUST provide shared services to plugins via the `ConfigureSharedServices`
  callback on `PluginOptions`; plugins MUST NOT reach into the host's `IServiceProvider`
  directly.
- Each plugin MUST build and own its own `IServiceProvider`; the host accesses plugin
  services exclusively through `IPluginServiceProvider`.
- Service lifetime contracts (singleton / scoped / transient) MUST be honoured across
  the plugin/host boundary exactly as documented in `PluginOptions.ConfigureSharedServices`.

**Rationale**: Consistent DI usage makes plugin services predictable, testable in isolation,
and replaceable without changing host code.

### III. Graceful Lifecycle Management

Plugin load and unload operations MUST be atomic with respect to observable state.

- A failed load MUST record a human-readable error on `IPlugin.Error` and MUST NOT
  prevent other plugins from loading.
- `PluginLoaded` MUST be raised after every load attempt (successful or not) so
  consumers can inspect `IPlugin.IsLoaded` and `IPlugin.Error`.
- `PluginUnloading` MUST be raised before disposal so consumers can release references
  to plugin services prior to context unload.
- `IPlugin` implementors MUST implement `IDisposable`; disposal MUST unload the
  `AssemblyLoadContext`, null service references, and set `IsLoaded = false`.
- Reloading a plugin (Unload → Load) MUST produce a fresh `AssemblyLoadContext` and
  a fresh `IServiceProvider`; stale references from the previous load MUST NOT be used.

**Rationale**: Lifecycle correctness prevents memory leaks (orphaned load contexts) and
ensures host stability when individual plugins fail or are updated at runtime.

### IV. Test-Driven Quality

All behavioural contracts MUST have corresponding xUnit integration tests using
FluentAssertions before a feature is considered complete.

- Service-lifetime behaviour (singleton, scoped, transient) across plugin/host boundaries
  MUST each have a dedicated test case.
- Dynamic load/unload/reload cycles MUST be covered by integration tests that assert
  plugin count, `IsInitialized` state, and service resolution after each operation.
- Tests that depend on built plugin DLLs (on-disk plugins) MUST be marked
  `[IgnoreOnCIFact]` or equivalent when the artifacts are not present in CI.
- The Red-Green-Refactor discipline MUST be applied: tests MUST fail before implementation
  is written.

**Rationale**: The plugin lifecycle has subtle timing and reference-counting constraints;
only running tests can reliably catch regressions introduced by .NET runtime upgrades or
refactoring.

### V. Semantic Versioning & Multi-Target Compatibility

The library MUST follow semantic versioning (`MAJOR.MINOR.PATCH`) as defined in
`Directory.Build.props` (`VersionPrefix`).

- Breaking changes to `IPlugin`, `IPluginsManager`, `IPluginServiceProvider`, or
  `PluginOptions` MUST increment the MAJOR version.
- New non-breaking public API additions MUST increment the MINOR version.
- Bug fixes and internal-only changes MUST increment the PATCH version.
- The library MUST maintain multi-target compatibility: `net6.0`, `net8.0`, `net9.0`.
  Removing a target framework MUST be treated as a breaking change (MAJOR bump).
- NuGet package metadata (`Company`, `RepositoryUrl`, `PackageTags`) MUST remain
  accurate in `Directory.Build.props`.

**Rationale**: Downstream consumers depend on stable, versioned contracts. Multi-targeting
ensures the plugin system is usable in host applications running any currently supported
.NET LTS or current release.

## Technical Constraints

- **Language & Runtime**: C# with nullable reference types enabled; `ImplicitUsings` enabled.
- **Core Dependencies**: `Microsoft.Extensions.DependencyInjection`, `Microsoft.Extensions.Logging.Abstractions`,
  `Microsoft.Extensions.Configuration.*` — all version-locked to the matching .NET target
  via `$(MicrosoftExtensionsVersion)`.
- **No External IoC**: Third-party IoC containers MUST NOT be introduced into the core
  `Juice.Plugins` library; the library MUST remain compatible with the standard
  `Microsoft.Extensions.DependencyInjection` container.
- **Plugin Startup Convention**: The `Startup` class discovery is convention-based
  (type name == `"Startup"`, non-abstract, with `ConfigureServices(IServiceCollection, IConfiguration)`
  method). This convention MUST NOT be changed without a MAJOR version bump.
- **Build Output**: All output paths MUST follow the layout defined in `Directory.Build.props`
  (`build/bin/$(Configuration)/$(MSBuildProjectName)`). Plugin test artifacts are resolved
  relative to this layout.

## Development Workflow

- **Branching**: Feature branches MUST be named `feature/<short-description>`;
  release branches MUST be named `release/<major>.<minor>`.
- **CI Gate**: CI MUST only build and run tests on the `main` branch and `release/*` branches
  (as configured). Plugin DLL tests using `[IgnoreOnCIFact]` are excluded from CI runs.
- **Pull Requests**: All PRs targeting `main` MUST pass a Constitution Check verifying
  compliance with the five core principles above.
- **Complexity Justification**: Any deviation from the isolation or DI-first principles
  (e.g., direct type-sharing, bypassing `IServiceProvider`) MUST be documented in the
  PR with an explicit justification and approved by a maintainer.
- **Commit Style**: Commits MUST use conventional commit prefixes
  (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`).

## Governance

This Constitution supersedes all other project practices and coding conventions.
Amendments require:

1. A written rationale describing the problem solved and the impact on existing principles.
2. Increment the `CONSTITUTION_VERSION` following semantic versioning rules above.
3. Update `LAST_AMENDED_DATE` to the amendment date.
4. Propagate changes to all affected templates (plan, spec, tasks) and command files.
5. A PR review by at least one maintainer before merging.

All PRs and code reviews MUST verify compliance with the Core Principles. Complexity
introduced beyond what the principles require MUST be justified in writing. Runtime
development guidance is maintained in this file and in `.specify/templates/`.

**Version**: 1.0.0 | **Ratified**: 2026-02-20 | **Last Amended**: 2026-02-20
