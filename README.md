# public-releases

Signed release artifacts, published from more than one mithrl-labs product's release
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
`mithrl-labs/lattice-kg`'s `.github/workflows/cli_release.yml`) carries:

- `manifest.json` — the version + per-platform `{url, sha256}` map
- `manifest.json.sig` — an Ed25519 detached signature over `manifest.json`
- One binary per supported platform (`mithrl-darwin-arm64`, `mithrl-linux-x86_64`,
  `mithrl-windows-amd64.exe`)

`mithrl update` (`cli/src/lattice_cli/update_client.py`) verifies `manifest.json`'s
signature against a public key embedded in the CLI before trusting anything in it —
this repo being public is not itself a trust boundary; the signature is. See
`cli/README_UPDATE.md` in `mithrl-labs/lattice-kg` for the full design.

### Installing a binary manually

Most people should just run `mithrl update` — this is for anyone who wants a
binary directly (e.g. no existing `mithrl` install to run `update` from).

One command picks the right binary for the machine it runs on, names it
`mithrl`, and makes it executable.

**macOS / Linux** (and Windows under Git Bash):

```sh
curl -fsSL https://raw.githubusercontent.com/mithrl-labs/public-releases/main/install-mithrl.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/mithrl-labs/public-releases/main/install-mithrl.ps1 | iex
```

Both drop the binary in the current directory. To put it straight on your
`PATH` instead:

```sh
curl -fsSL https://raw.githubusercontent.com/mithrl-labs/public-releases/main/install-mithrl.sh | MITHRL_INSTALL_DIR=~/.local/bin sh
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/mithrl-labs/public-releases/main/install-mithrl.ps1))) -InstallDir "$HOME\bin"
```

The script finds the newest release tagged `lattice-cli/*` (GitHub's own
"Latest" marker is repo-wide — see "Tag namespacing" above), downloads the
asset for this platform, and checks its SHA-256 against that release's
`manifest.json` before installing anything. It refuses to install on a
mismatch, and fails with a specific message on platforms that have no build
yet (Intel Mac, ARM Linux, ARM Windows).

That checksum catches a corrupt, truncated or wrong-asset download. It is not
a signature check: `manifest.json` arrives over HTTPS and its `manifest.json.sig`
is not verified here, because that needs the public key embedded in the CLI.
`mithrl update` does verify it — see "Mithrl-1 CLI" above.

Piping a script into a shell means trusting what this URL serves at the moment
you run it. To read it first:

```sh
curl -fsSL https://raw.githubusercontent.com/mithrl-labs/public-releases/main/install-mithrl.sh -o install-mithrl.sh
less install-mithrl.sh
sh install-mithrl.sh
```

<details>
<summary>Prefer the <code>gh</code> CLI?</summary>

```sh
TAG=$(gh release list --repo mithrl-labs/public-releases --json tagName,publishedAt \
  --jq 'map(select(.tagName | startswith("lattice-cli/"))) | sort_by(.publishedAt) | reverse | .[0].tagName')
gh release download "$TAG" --repo mithrl-labs/public-releases --pattern 'mithrl-darwin-arm64'  # or -linux-x86_64 / -windows-amd64.exe
mv mithrl-darwin-arm64 mithrl && chmod u+rwx mithrl  # adjust the source name to match whichever pattern you used above
```

`gh` handles the tag's `/` correctly on its own — no percent-encoding needed
here. Requires `gh auth login` first, even for this public repo; `gh`
refuses to run at all otherwise. This path does no checksum check.

</details>

## No source code here

This repo intentionally contains no application source — only release assets
and this README. Each product's source lives in its own repo (the mithrl
CLI's is `mithrl-labs/lattice-kg/cli/`).
