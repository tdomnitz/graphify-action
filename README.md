# graphify-action

Runs [`graphify update`](https://pypi.org/project/graphifyy/) against a checked-out
repository inside a container, so you can keep a `graphify-out/` knowledge graph in
sync with your code. This action only runs graphify — it never commits, pushes, or
opens a PR. Your workflow decides what happens to the result.

## Usage

```yaml
name: Update graph

on:
  push:
    branches: [main]

permissions:
  contents: write # needed for the commit/push step below

jobs:
  update-graph:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: graphify
        uses: tdomnitz/graphify-action@v1
        with:
          path: .
          gemini-api-key: ${{ secrets.GEMINI_API_KEY }}

      - if: steps.graphify.outputs.changed == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add graphify-out
          git commit -m "chore: update graphify graph"
          git push
```

`changed` is scoped to `path`/`graphify-out`, the action's own output location —
it reflects only what `graphify update` itself modified, so it stays `"false"`
even if an earlier step in your job leaves unrelated files dirty.

The example above also needs `permissions: contents: write`, since repos and
organizations created since early 2023 default the workflow's `GITHUB_TOKEN` to
read-only, which makes `git push` fail with a 403.

**First-time setup:** a GHCR package pushed from a personal account starts out
private. After the first `publish.yml` run, go to the package's settings on
GHCR and make it public — otherwise consumers' pulls of `ghcr.io/tdomnitz/graphify-action:v1`
will fail.

## Inputs

| input | default | description |
|---|---|---|
| `path` | `.` | Directory to run `graphify update` against, relative to the workspace. |
| `gemini-api-key` | *(empty)* | Optional Gemini API key, forwarded as `GEMINI_API_KEY` for semantic extraction of docs/papers/images. |
| `graphify-version` | *(empty)* | Optional `graphifyy` version to install at runtime, overriding the version baked into the image. |
| `extra-args` | *(empty)* | Optional extra flags appended to the `graphify update` command line, e.g. `--mode deep`. |

## Outputs

| output | description |
|---|---|
| `changed` | `"true"` or `"false"` — whether `graphify update` left the workspace with uncommitted changes. |

## Third-party notices

This action's image bundles [graphify](https://github.com/Graphify-Labs/graphify)
(Apache License 2.0). See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
