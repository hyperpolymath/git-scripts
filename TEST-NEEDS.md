# TEST-NEEDS — git-scripts

## CRG Grade: C — ACHIEVED 2026-04-04

All required test categories for CRG Grade C are present and passing.

### Test Inventory

| Category | Status | Location | Count |
|---|---|---|---|
| Unit | PASS | `test/script_manager_test.exs` | 21 |
| Smoke | PASS | `test/script_manager_test.exs` | 6 |
| Property-based (P2P) | PASS | `test/script_manager_test.exs` (StreamData) | 5 |
| E2E | PASS | `test/script_manager_test.exs` | 3 |
| Contract | PASS | `test/script_manager_test.exs` | 5 |
| Aspect | PASS | `test/script_manager_test.exs` | 7 |
| Benchmarks | PENDING | Benchee to be added once gossamer Hex dep resolved | — |

Total tests: **47** (5 properties + 42 ExUnit tests)

### Commands

```sh
# Run all tests
mix test

# Run a specific test file
mix test test/script_manager_test.exs
```

### Notes

- `stream_data ~> 1.0` added as test-only dep for property tests.
- `gossamer` git dep temporarily commented out (no mix.exs in the repo root).
- `web_interface.ex` stubbed to compile without `Gossamer.Web` macro.
- `http_client.ex` pre-existing `\` default arg syntax fixed to `\\`.

### Next: CRG Grade B

Requires 6 quality targets.
See `.machine_readable/STATE.a2ml` for details.
