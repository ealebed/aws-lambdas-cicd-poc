# Dependabot automation

Minor and patch Dependabot pull requests are approved and squash-merged by the `automerger` GitHub App after required CI passes. Major and non-semver updates stay open for manual review.

See [ADR-001](decisions/001-dependabot-auto-merge.md) for why a GitHub App is used and why code-owner reviews are **not** a merge gate.

## How it works

```mermaid
sequenceDiagram
  participant Dependabot
  participant Actions as GitHubActions
  participant App as AutomergerApp
  participant GH as GitHubMergeGate

  Dependabot->>GH: Open minor or patch PR
  GH->>Actions: pull_request event
  Actions->>Actions: Detect Changed Lambdas
  Actions->>Actions: Language validation if Lambda dirs changed
  Actions->>Actions: PR checks aggregate
  Actions->>Actions: Dependabot auto-merge workflow
  Actions->>Actions: fetch-metadata update-type
  alt semver-minor or semver-patch
    Actions->>App: Mint installation token
    Actions->>GH: gh pr review --approve
    Actions->>GH: gh pr merge --auto --squash
    GH->>GH: Wait for required checks
    GH->>GH: Squash merge to master
  else major or unknown
    Actions->>Actions: Skip approve and merge
  end
```

What gets auto-merged:

- `version-update:semver-minor`
- `version-update:semver-patch`

What stays manual:

- `version-update:semver-major`
- `version-update:semver-unknown` (typical for some Docker tags)
- Any PR not authored by `dependabot[bot]`

`--auto` does **not** wait inside the job. GitHub merges later, only if branch protection is satisfied. If required status checks are missing, GitHub can squash-merge as soon as the App approves.

## Repository files

- [`.github/workflows/dependabot-auto-merge.yml`](../.github/workflows/dependabot-auto-merge.yml) — approve + enable squash auto-merge
- [`.github/dependabot.yml`](../.github/dependabot.yml) — daily gomod (`lambdas/go/*`), docker (`lambdas/*`), and github-actions; `dependencies` label, assignee `@ealebed`
- [`.github/CODEOWNERS`](../.github/CODEOWNERS) — review requests to `@ealebed` (not a merge requirement)
- [`.github/workflows/wfl_pr_validation.yml`](../.github/workflows/wfl_pr_validation.yml) — `PR checks` job is the merge gate

The auto-merge workflow never checks out the pull request branch.

Python `requirements.txt` and JavaScript `package.json` are not in Dependabot today.

## GitHub App

App: `automerger` (user-owned). Webhook disabled. Installed on selected repositories.

Repository permissions:

- **Contents**: Read and write (merge)
- **Pull requests**: Read and write (approve, enable auto-merge)
- **Metadata**: Read-only (required)

The workflow mints a short-lived installation token with [`actions/create-github-app-token@v3`](https://github.com/actions/create-github-app-token) using **Client ID** + private key PEM. Do not use an OAuth client secret.

[Making authenticated API requests with a GitHub App in a workflow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow)

## Secrets

Dependabot-triggered `pull_request` jobs only see **Dependabot** secrets, not Actions secrets or variables. Store the **same names** in both stores:

```mermaid
flowchart LR
  subgraph stores [Secret stores]
    ActionsSecrets[Actions secrets]
    DependabotSecrets[Dependabot secrets]
  end
  subgraph names [Identical names]
    ClientId[APP_CLIENT_ID]
    PrivateKey[APP_PRIVATE_KEY]
  end
  ActionsSecrets --> ClientId
  ActionsSecrets --> PrivateKey
  DependabotSecrets --> ClientId
  DependabotSecrets --> PrivateKey
  ClientId --> Workflow[dependabot-auto-merge.yml]
  PrivateKey --> Workflow
```

| Name | Store | Value |
| --- | --- | --- |
| `APP_CLIENT_ID` | Actions **and** Dependabot secrets | GitHub App Client ID (`Iv1…` / `Iv23…`) |
| `APP_PRIVATE_KEY` | Actions **and** Dependabot secrets | Full PEM, including BEGIN/END lines |

If a Dependabot run fails with an empty Client ID or private key, the values were added only under Actions secrets.

## Branch protection (`master`)

Required so auto-merge cannot skip CI:

- Require a pull request before merging
- Required approving reviews: **1**
- **Do not** require review from Code Owners
- Dismiss stale reviews when new commits are pushed (the workflow re-approves on `synchronize`)
- Require status checks to pass before merging
- Required check: `PR checks` (from [PR Validation](../.github/workflows/wfl_pr_validation.yml)). It succeeds when `Detect Changed Lambdas` succeeded and each language validate job is `success` or `skipped`.
- Do **not** require `Validate Python Lambda - ${{ matrix.lambda }}` (and the JS/Go equivalents). Those names are what GitHub reports when the matrix job is skipped.
- Do **not** require Lambdas Release jobs (`Determine Environment`, deploy). That workflow runs on push to `master` / `workflow_dispatch`, not on PRs.
- If `Detect Changed Lambdas` was already required, you can keep it; `PR checks` is the one that also waits for language validation.
- Require conversation resolution: **off**
- Allow auto-merge: **on**
- Squash merging: **on**
- No force pushes, no deletions

## Rollout order

1. Open this change so `PR checks` appears in Checks.
2. Add `PR checks` as a required status check.
3. Confirm App install, `APP_CLIENT_ID` / `APP_PRIVATE_KEY` in both secret stores, auto-merge, and squash.
4. Merge into `master`.

If only `Detect Changed Lambdas` is required, a Go module Dependabot PR can squash-merge while `Validate Go Lambda` is red.

## Verify

1. Minor or patch Go Dependabot PR: App approval, auto-merge queued, squash merge after `PR checks` is green (includes that Lambda’s validate job).
2. Actions or shared-Dockerfile Dependabot PR: validate jobs skip; `PR checks` still green after detect.
3. Major or `semver-unknown` Dependabot PR: workflow runs, no App approval, PR stays open.
4. Human PR: auto-merge job skipped (`dependabot[bot]` guard).
5. On a Dependabot-triggered run, `Create GitHub App token` can read both secrets.
