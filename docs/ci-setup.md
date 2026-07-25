# CI Setup

This repo runs GitHub Actions on every pull request and every push to `main`, defined in
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## What the workflow does

### `local-checks`

No org required. Checks out the repo, installs Node (version read from `.tool-versions`,
falling back to Node 24 if that file is missing the `nodejs` line), runs `npm ci`, then:

- `npm run prettier:verify` - formatting check
- `npm run lint` - ESLint over `aura`/`lwc` JS
- `npm run test:unit:coverage` - LWC Jest unit tests with coverage

### `code-analyzer`

No org required. Installs Python (needed by Code Analyzer's `flow` engine - see
[Gotchas](#gotchas) below), installs the Salesforce CLI (`sf`) via npm, installs the
`code-analyzer` plugin pinned to `5.2.2` (matching the version validated locally), and runs:

```
sf code-analyzer run --workspace force-app --view detail --severity-threshold High \
  --output-file analysis-results/code-analyzer-results.json \
  --output-file analysis-results/code-analyzer-results.html
```

`--severity-threshold High` makes the command (and therefore the job) exit non-zero if any
Critical or High severity violation is found. Results are uploaded as a build artifact
(`code-analyzer-results`, JSON + HTML) regardless of pass/fail, so a failure can be
inspected without re-running locally.

A handful of PMD `ApexCRUDViolation` findings are intentionally left in place and
suppressed in code with `@SuppressWarnings('PMD.ApexCRUDViolation')` plus a comment
explaining why (queries against `Ack_Setting__mdt`, `EmailTemplate`, and
`OrgWideEmailAddress` - all admin-configured setup/config metadata that end users
legitimately lack object/field permissions on; enforcing `WITH USER_MODE` there would
break the feature for non-admin users, not make it safer). If Code Analyzer starts
flagging genuinely new High/Critical findings, this job is the gate that catches them.

### `apex-tests`

Requires the `DEVHUB_SFDX_AUTH_URL` secret (see [Manual setup](#manual-setup-required)
below). Deploys the package to a fresh scratch org via CumulusCI and runs the full Apex
test suite (38 tests as of this writing). Steps:

1. Install Python, the Salesforce CLI, and CumulusCI (via `pipx`, with the
   `keyrings.alt` gotcha handled - see below).
2. Authenticate the Dev Hub from the `DEVHUB_SFDX_AUTH_URL` secret
   (`sf org login sfdx-url --sfdx-url-stdin --set-default-dev-hub`).
3. Connect CumulusCI's `github` service using the workflow's own `GITHUB_TOKEN` (see
   below).
4. `cci flow run ci_feature --org dev --no-prompt` - creates the scratch org (CumulusCI
   provisions it automatically on first use of the `dev` org name), deploys, and runs
   Apex tests.
5. **Always** (`if: always()`) deletes the scratch org with
   `cci org scratch_delete dev`, even if the flow failed, so failed runs don't leak
   scratch orgs against the Dev Hub's org limits.

This job is **skipped, not failed**, when `DEVHUB_SFDX_AUTH_URL` isn't set - see
[Manual setup](#manual-setup-required).

## Manual setup required

The only manual step is creating the `DEVHUB_SFDX_AUTH_URL` repository secret. Everything
else in the workflow is self-contained.

1. Authenticate a Dev Hub-enabled org locally if you haven't already (`sf org login web
--set-default-dev-hub`).
2. Get its SFDX auth URL:

   ```
   sf org display --verbose --target-org cuzelac@lamplighters.org
   ```

   Copy the value of **Sfdx Auth Url** from the output. (This is only shown for orgs
   authenticated via the web login flow, not JWT.)

3. In the GitHub repo: **Settings > Secrets and variables > Actions > New repository
   secret**. Name it `DEVHUB_SFDX_AUTH_URL` and paste the URL as the value.

Treat this URL as a credential - anyone with it can authenticate as your Dev Hub. Only
store it as a GitHub Actions secret, never in a file that gets committed.

Until this secret exists, `apex-tests` shows as skipped on every run; `local-checks` and
`code-analyzer` work with no setup at all.

## Gotchas

- **`keyrings.alt` is required, not optional.** CumulusCI's local keychain (where it
  stores encrypted org/service credentials between task invocations within a run) uses
  the Python `keyring` library, which by default expects an OS-level keyring backend -
  the Secret Service API on Linux (usually via `gnome-keyring` or a polkit agent), macOS
  Keychain, or Windows Credential Manager. GitHub-hosted runners have none of these.
  Without `keyrings.alt` injected into the same pipx-managed virtualenv as CumulusCI
  (`pipx inject cumulusci keyrings.alt`), `cci` calls fail trying to reach a keyring
  backend that doesn't exist. `keyrings.alt` provides a file-based fallback backend that
  works headlessly.
- **The `github` service must be connected before the flow runs, or dependency
  resolution can fail.** `ci_feature` resolves this project's NPSP dependency
  (`SalesforceFoundation/NPSP` on GitHub) as part of the `update_dependencies` task,
  which means it makes GitHub API calls. Unauthenticated GitHub API requests are capped
  at 60/hour per IP - trivial to exhaust on a shared GitHub-hosted runner pool - while
  requests authenticated with a token get a much higher limit. The workflow's built-in
  `GITHUB_TOKEN` (automatically provided by GitHub Actions, no secret setup needed) is
  sufficient; it's connected with `cci service connect github --username ... --email ...
--token "$GITHUB_TOKEN" --project` before the flow runs. `--project` scopes the
  service to this repo's checkout rather than writing to a global config.
- **The Code Analyzer `flow` engine needs Python 3.10+ on `PATH`.** Without it, the
  engine fails to instantiate with a Critical-severity `UninstantiableEngineError` - a
  tooling/environment problem, not a real finding about our code - which would fail the
  `code-analyzer` job for the wrong reason. The workflow installs Python via
  `actions/setup-python` before running the analyzer specifically to avoid this. (This
  bit locally too: this repo's `.tool-versions` only pins a Node version, so a bare
  `python3` doesn't resolve as an asdf shim unless a Python version is separately
  selected/pinned.)
- **`apex-tests` always deletes its scratch org**, even on failure
  (`if: always()` on the cleanup step), because CumulusCI scratch orgs count against the
  Dev Hub's active-scratch-org limit. A failed run that leaks orgs will eventually start
  blocking every subsequent run until they expire or are cleaned up manually.
- **`ci_feature` includes a couple of GitHub-writing steps** (`github_parent_pr_notes`,
  `github_automerge_feature`) inherited from CumulusCI's universal flow definition. They
  no-op when their preconditions aren't met (no parent PR, branch doesn't match the
  feature-branch prefix) rather than failing the flow, but they do need a `GITHUB_TOKEN`
  with write access to behave correctly when their preconditions _are_ met. The default
  `GITHUB_TOKEN` has write access for same-repo pull requests; PRs from forks get a
  read-only token, which is a known limitation if this repo ever accepts fork PRs.
