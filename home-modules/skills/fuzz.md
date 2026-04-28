---
name: fuzz
description: Use this skill whenever the user wants to fuzz a codebase, generate adversarial or property-based tests, find crashers, verify parsers/validators/CLIs against malformed inputs, generate proof-of-vulnerability repros, or run a PBFuzz-style agentic bug-finding loop. Also use it for prompts like "find edge case bugs", "test all inputs", "try weird inputs", "fuzz this parser", or "use subagents to find bugs" even if the user does not say "fuzz".
---

# Fuzz

Run a pragmatic, PBFuzz-inspired workflow for finding real bugs with generated inputs, semantic properties, examples, and deterministic repros.

The skill should make the agent more effective at bug-finding, not merely more random. First understand the input surface and expected invariants, then generate structured bad inputs that exercise likely failure modes.

## Operating Mode

- Prefer action over extended planning once enough context is available.
- Keep context gathering bounded: search broadly once, fan out to focused subagents if the repo is large, then start testing the highest-value target.
- Ask the user only when authorization, dependency changes, destructive behavior, or target scope is unclear.
- If the user asks for analysis only, do not edit files; otherwise create minimal tests or harnesses when they are useful.
- Treat confirmed failures as bugs only after producing a deterministic repro.

## Safety And Scope

- Fuzz only code the user owns or is authorized to test.
- Default to local code, local tests, examples, CLIs, parsers, pure functions, libraries, and fixtures.
- Do not fuzz public services, third-party systems, production endpoints, or network targets without explicit authorization and scope.
- Avoid destructive payloads unless the target is an isolated local fixture.
- Put resource bounds on every run: timeout, iteration count, input size, temp directory, and corpus size.
- Prefer deterministic regression tests over long-running fuzz campaigns in normal coding sessions.

## Quick Start Workflow

Use this path for most requests.

1. Discover fuzzable surfaces with one broad search pass.
2. Rank targets by bug likelihood, impact, and ease of harnessing.
3. Pick the best target unless the user gave one explicitly.
4. Infer 3-7 semantic properties or invariants from code, docs, fixtures, and tests.
5. Add the smallest useful generated-input test or deterministic boundary test using existing project tooling.
6. Run the existing relevant tests/examples first to establish a baseline.
7. Run the new test with tight bounds.
8. Minimize any failure into a deterministic regression case.
9. Fix local confirmed bugs when in scope, then rerun the regression and relevant suite.
10. Report exact commands, inputs, files changed, and remaining high-value targets.

## Context Gathering

Search for:

- Parsers, decoders, deserializers, lexers, config readers, importers.
- Validators, normalizers, canonicalizers, encoders, serializers.
- CLI command handlers and argument parsers.
- Public functions taking strings, bytes, JSON, paths, URLs, numbers, datetimes, regexes, maps, arrays, or user-controlled collections.
- Protocol handlers, state machines, round-trip encode/decode pairs, and migration code.
- Existing tests, table-driven cases, examples, fixtures, sample inputs, benchmarks, and corpus directories.
- Risk markers: panics, `unwrap`, unchecked indexing, manual bounds logic, recursion, regex parsing, custom escaping, integer math, path joining, type coercion, timeout-prone loops, or ad hoc serialization.

Stop gathering context when:

- You can name one or more exact target functions/files and the likely bug class.
- Existing tests or examples show the expected contract.
- Additional searching is unlikely to change the first target.

Search again only if validation fails, the harness cannot be built, or the failure points to a different area.

## Subagent Use

Use subagents when the scope is broad, the repo has multiple languages/modules, or the user explicitly asks to fan out. Keep each subagent scoped and ask for concrete artifacts.

Useful subagents:

- Surface mapper: find fuzzable files, functions, CLIs, examples, and tests.
- Invariant analyst: read one target and list semantic properties plus edge cases.
- Harness designer: propose the minimal test/harness using existing dependencies.
- Runner: run bounded tests/examples and capture commands, output, and failures.
- Reproducer: minimize failing input into a deterministic test case.
- Fixer: patch confirmed local bugs and verify regression tests.

Each subagent should return:

- Files inspected.
- Candidate targets and risk ranking.
- Contracts or invariants inferred.
- Suggested harness location.
- Exact commands run or recommended.
- Confirmed failures with minimized inputs and stack traces.

## Target Ranking

Prefer targets with:

- Complex parsing, validation, normalization, or state transitions.
- Security or data-integrity impact.
- Existing fixtures/examples that make valid input generation cheap.
- Sparse invalid-input tests.
- Clear properties such as round-trip, idempotence, no-panic, canonical form, or reject-invalid.

Defer targets that need large infrastructure, real credentials, network services, or broad dependency additions unless the user asks for deep fuzzing.

## Harness Rules

Follow the repository's existing test style and dependency pattern.

- Rust: prefer existing tests first; use `proptest`, `quickcheck`, or `cargo fuzz` only if already present or approved.
- Go: prefer native `testing.F` fuzz tests when practical.
- Python: prefer `hypothesis` if already present; otherwise start with deterministic generated cases.
- JavaScript/TypeScript: prefer the existing runner; use `fast-check` only if already present or approved.
- C/C++: prefer existing harnesses and sanitizers; use libFuzzer/AFL only when project tooling supports them.
- Nix projects: use `flake.nix`, `nix develop`, or declared dev shells. Do not install tools imperatively.

If a new dependency would materially improve results, explain the value and ask before adding it.

## Good Properties

Choose properties that test behavior rather than reimplementing the code.

- Arbitrary malformed input should not panic, hang, or exhaust resources.
- `decode(encode(x))` should preserve valid values.
- `normalize(normalize(x))` should equal `normalize(x)`.
- Invalid input should return documented errors, not partial success.
- Canonicalization should be stable across equivalent inputs.
- Validation should reject malformed nesting, invalid encodings, duplicate keys, truncated data, and boundary sizes.
- Limits should cap recursion, collection sizes, numeric ranges, input length, and path traversal.

Avoid properties that simply duplicate implementation details or accept any output as success.

## Failure Handling

When a fuzz/property test fails:

1. Preserve the exact failing input before changing code.
2. Reduce the input using framework shrinking, manual minimization, or a small deterministic fixture.
3. Decide whether the failure is a real bug, test bug, unclear contract, or expected rejection.
4. Add a regression test for real bugs before or alongside the fix.
5. Patch only the minimal code needed to satisfy the contract.
6. Rerun the regression, the generated-input test, and relevant existing tests.

Do not report a vague "possible bug" as found unless there is a reproducible command and input.

## Deep Mode

Use a deeper workflow when the user asks for "deep", "thorough", "go through everything", or similar.

1. Spawn surface-mapping subagents by directory, package, or language.
2. Merge and deduplicate target lists.
3. Pick the top 3-5 targets by risk and harnessability.
4. For each target, run the quick workflow independently.
5. Summarize explored and unexplored surfaces so follow-up fuzzing is easy.

Deep mode should still use bounded runs. Depth means broader target coverage, not unbounded execution.

## Report Format

Use this final structure:

```markdown
**Fuzzing Results**
- Targets explored: ...
- Bugs found: ...
- Files changed: ...
- Verification: ...
- Remaining targets: ...
```

For each bug, include:

- File/line or symbol.
- Expected behavior.
- Actual behavior.
- Minimized input.
- Repro command.
- Fix summary, if fixed.

If no bugs are found, say that explicitly and list the strongest remaining targets or longer-running campaigns worth doing next.
