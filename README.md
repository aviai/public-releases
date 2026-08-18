# public-releases

Signed release artifacts, published from more than one aviai product's release
CI — no application source, only release assets and this README. This repo is
deliberately public and separate from any product's own (private/internal)
source repo, so each product's self-update/install flow can fetch its manifest
and binaries without requiring any authentication or org membership.

## Tag namespacing

Because this repo hosts more than one product, every release is tagged
`<product>/<tag>` rather than a bare version tag — e.g. the mithrl CLI's
releases are tagged `lattice-cli/cli-v0.2.0`, not `cli-v0.2.0`. This exists to
avoid one product's tags colliding with another's, and because **GitHub's own
"Latest" release marker is repo-wide, not per-product** — confirmed
empirically, it lands on whichever release was published most recently across
every product sharing this repo, not the most recent release of the one you
care about. Don't rely on `.../releases/latest` (the web UI's "Latest" badge,
`gh release list`'s `Latest` column, or the `/releases/latest/download/<asset>`
URL shortcut) to mean "latest for my product" — filter this repo's release
list by tag prefix instead (see below). `mithrl update` itself does exactly
this (`update_client.py`'s `_resolve_manifest_urls`, filtering on
`lattice-cli/`).

Note the prefix is `lattice-cli/`, not `mithrl/`: the CLI was renamed from
`Lattice` to `mithrl` (ENG-2977), but this prefix is a release-lookup key that
already-installed binaries filter on, so it is deliberately left alone. Match
on `lattice-cli/` for tags and `mithrl` for asset/binary names.

## Mithrl-1 CLI

Each GitHub Release tagged `lattice-cli/cli-v*` (published by
`aviai/lattice-kg`'s `.github/workflows/cli_release.yml`) carries:

- `manifest.json` — the version + per-platform `{url, sha256}` map
- `manifest.json.sig` — an Ed25519 detached signature over `manifest.json`
- One binary per supported platform (`mithrl-darwin-arm64`, `mithrl-linux-x86_64`,
  `mithrl-windows-amd64.exe`)

`mithrl update` (`cli/src/lattice_cli/update_client.py`) verifies `manifest.json`'s
signature against a public key embedded in the CLI before trusting anything in it —
this repo being public is not itself a trust boundary; the signature is. See
`cli/README_UPDATE.md` in `aviai/lattice-kg` for the full design.

### Installing a binary manually

Most people should just run `mithrl update` — this is for anyone who wants a
binary directly (e.g. no existing `mithrl` install to run `update` from).
Each command below finds the latest `lattice-cli/*` release and downloads the
right binary for that platform — no `gh` CLI or login required, just `curl`
(macOS/Linux, both preinstalled) or PowerShell (Windows, preinstalled).

**macOS (Apple Silicon only — no Intel Mac build yet):**

```sh
TAG=$(curl -s "https://api.github.com/repos/aviai/public-releases/releases?per_page=100" | grep -m1 '"tag_name": "lattice-cli/' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
[ -n "$TAG" ] || { echo "No lattice-cli/* release found" >&2; exit 1; }
curl -fL -o mithrl "https://github.com/aviai/public-releases/releases/download/${TAG//\//%2F}/mithrl-darwin-arm64" && chmod 755 mithrl && ./mithrl --version
```

**Linux (x86_64 only — no ARM Linux build yet):**

```sh
TAG=$(curl -s "https://api.github.com/repos/aviai/public-releases/releases?per_page=100" | grep -m1 '"tag_name": "lattice-cli/' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
[ -n "$TAG" ] || { echo "No lattice-cli/* release found" >&2; exit 1; }
curl -fL -o mithrl "https://github.com/aviai/public-releases/releases/download/${TAG//\//%2F}/mithrl-linux-x86_64" && chmod 755 mithrl && ./mithrl --version
```

**Windows (PowerShell):**

```powershell
$tag = (Invoke-RestMethod "https://api.github.com/repos/aviai/public-releases/releases?per_page=100" | Where-Object { $_.tag_name -like "lattice-cli/*" } | Select-Object -First 1).tag_name
if (-not $tag) { throw "No lattice-cli/* release found" }
Invoke-WebRequest -Uri "https://github.com/aviai/public-releases/releases/download/$($tag -replace '/', '%2F')/mithrl-windows-amd64.exe" -OutFile mithrl.exe
.\mithrl.exe --version
```

If `./mithrl --version` (or `.\mithrl.exe --version`) prints a version
string, it worked — move the binary wherever you keep executables on your
`PATH` (e.g. `sudo mv mithrl /usr/local/bin/` on macOS/Linux).

All three rely on the GitHub API returning releases newest-first (its
documented default — `mithrl update` relies on the same ordering, see
`update_client.py`'s `_resolve_manifest_urls`) and take the first one tagged
`lattice-cli/*`, since neither the web UI's "Latest" badge nor
`/releases/latest` can be trusted here (see "Tag namespacing" above). They
percent-encode that tag's `/` as `%2F` before building the download URL —
required because GitHub 404s on a literal `/` inside a release tag path
segment (confirmed empirically; treats it as a path separator, not part of
an opaque tag name).

<details>
<summary>Prefer the <code>gh</code> CLI?</summary>

```sh
TAG=$(gh release list --repo aviai/public-releases --json tagName,publishedAt \
  --jq 'map(select(.tagName | startswith("lattice-cli/"))) | sort_by(.publishedAt) | reverse | .[0].tagName')
gh release download "$TAG" --repo aviai/public-releases --pattern 'mithrl-darwin-arm64'  # or -linux-x86_64 / -windows-amd64.exe
mv mithrl-darwin-arm64 mithrl && chmod 755 mithrl  # adjust the source name to match whichever pattern you used above
```

`gh` handles the tag's `/` correctly on its own — no percent-encoding needed
here. Requires `gh auth login` first, even for this public repo; `gh`
refuses to run at all otherwise.

</details>

## No source code here

This repo intentionally contains no application source — only release assets
and this README. Each product's source lives in its own repo (the mithrl
CLI's is `aviai/lattice-kg/cli/`).
