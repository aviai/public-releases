# public-releases

Signed release artifacts for the **Lattice CLI** (`aviai/lattice-kg`'s `cli/`
workspace member) — nothing else. This repo is deliberately separate from
`aviai/lattice-kg` (which is private/internal) so `Lattice update`'s self-update
flow can fetch its manifest and platform binaries without requiring any
authentication or org membership.

## What lives here

Each GitHub Release published by `aviai/lattice-kg`'s `.github/workflows/cli_release.yml`
carries:

- `manifest.json` — the version + per-platform `{url, sha256}` map
- `manifest.json.sig` — an Ed25519 detached signature over `manifest.json`
- One binary per supported platform (`Lattice-darwin-arm64`, `Lattice-linux-x86_64`,
  `Lattice-windows-amd64.exe`)

`Lattice update` (`cli/src/lattice_cli/update_client.py`) verifies `manifest.json`'s
signature against a public key embedded in the CLI before trusting anything in it —
this repo being public is not itself a trust boundary; the signature is. See
`cli/README_UPDATE.md` in `aviai/lattice-kg` for the full design.

## No source code here

This repo intentionally contains no application source — only release assets and
this README. The Lattice CLI's source lives in `aviai/lattice-kg/cli/`.
