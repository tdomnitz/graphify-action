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
          git diff --cached --quiet || git commit -m "chore: update graphify graph"
          git push
```

`changed` reflects `git status --porcelain` across the whole workspace, not just
`graphify-out/` — if an earlier step in your job also leaves files modified,
`changed` will be `"true"` even though graphify itself didn't change anything.
The `git diff --cached --quiet ||` guard above keeps the commit step from failing
with "nothing to commit" in that case.

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
