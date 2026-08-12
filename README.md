# public-releases

Signed release artifacts, published from more than one aviai product's release
CI — no application source, only release assets and this README. This repo is
deliberately public and separate from any product's own (private/internal)
source repo, so each product's self-update/install flow can fetch its manifest
and binaries without requiring any authentication or org membership.

## Tag namespacing

Because this repo hosts more than one product, every release is tagged
`<product>/<tag>` rather than a bare version tag — e.g. the Lattice CLI's
releases are tagged `lattice-cli/cli-v0.2.0`, not `cli-v0.2.0`. This exists to
avoid one product's tags colliding with another's, and because **GitHub's own
"Latest" release marker is repo-wide, not per-product** — confirmed
empirically, it lands on whichever release was published most recently across
every product sharing this repo, not the most recent release of the one you
care about. Don't rely on `.../releases/latest` (the web UI's "Latest" badge,
`gh release list`'s `Latest` column, or the `/releases/latest/download/<asset>`
URL shortcut) to mean "latest for my product" — filter this repo's release
list by tag prefix instead (see below). `Lattice update` itself does exactly
this (`update_client.py`'s `_resolve_manifest_urls`, filtering on
`lattice-cli/`).

## Lattice CLI

Each GitHub Release tagged `lattice-cli/cli-v*` (published by
`aviai/lattice-kg`'s `.github/workflows/cli_release.yml`) carries:

- `manifest.json` — the version + per-platform `{url, sha256}` map
- `manifest.json.sig` — an Ed25519 detached signature over `manifest.json`
- One binary per supported platform (`Lattice-darwin-arm64`, `Lattice-linux-x86_64`,
  `Lattice-windows-amd64.exe`)

`Lattice update` (`cli/src/lattice_cli/update_client.py`) verifies `manifest.json`'s
signature against a public key embedded in the CLI before trusting anything in it —
this repo being public is not itself a trust boundary; the signature is. See
`cli/README_UPDATE.md` in `aviai/lattice-kg` for the full design.

### Fetching a binary manually

Most people should just run `Lattice update` — this is for anyone who wants a
binary directly (e.g. no existing `Lattice` install to run `update` from).

Find the latest lattice-cli release (don't use `gh release view --repo
aviai/public-releases` with no tag, or the web UI's "Latest" release — see
"Tag namespacing" above for why; `gh release list`'s tag isn't its first
column, so a plain `grep '^lattice-cli/'` on its table output won't match —
filter on the actual `tagName` field instead):

```sh
gh release list --repo aviai/public-releases --json tagName,publishedAt \
  --jq 'map(select(.tagName | startswith("lattice-cli/"))) | sort_by(.publishedAt) | reverse | .[0].tagName'
```

Download a binary for a specific release, once you have its tag:

```sh
gh release download lattice-cli/cli-v0.2.0 --repo aviai/public-releases --pattern 'Lattice-darwin-arm64'
```

Without the `gh` CLI: a namespaced tag's assets are NOT reliably reachable at
the "obvious" URL — `.../releases/download/lattice-cli/cli-v0.2.0/<asset>`
404s, because GitHub treats the literal `/` inside the tag as a path
separator rather than as part of an opaque tag name (confirmed empirically;
`update_client.py`'s own asset-fetch code has the same finding written up in
more detail). Percent-encode the tag's `/` as `%2F` instead:

```sh
curl -LO 'https://github.com/aviai/public-releases/releases/download/lattice-cli%2Fcli-v0.2.0/Lattice-darwin-arm64'
```

## No source code here

This repo intentionally contains no application source — only release assets
and this README. Each product's source lives in its own repo (the Lattice
CLI's is `aviai/lattice-kg/cli/`).
