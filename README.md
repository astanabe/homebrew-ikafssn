# homebrew-ikafssn

Homebrew tap for [ikafssn](https://github.com/astanabe/ikafssn).

## Installation

```
brew tap astanabe/ikafssn
brew install ikafssn
```

## How this tap works

`Formula/ikafssn.rb` pins three things per release:

- the source tarball URL (`https://github.com/astanabe/ikafssn/archive/refs/tags/vX.Y.YYYY.MM.DD.tar.gz`) and its SHA256
- the bottle `root_url` (`https://github.com/astanabe/ikafssn/releases/download/vX.Y.YYYY.MM.DD`)
- the `arm64_tahoe` bottle SHA256

The bottle (`ikafssn-X.Y.YYYY.MM.DD.arm64_tahoe.bottle.tar.gz`) is uploaded as
a GitHub Release asset by ikafssn's
[`release.yml`](https://github.com/astanabe/ikafssn/blob/main/.github/workflows/release.yml)
workflow on `macos-26` (Apple Silicon).

## Release flow

When ikafssn is released, the formula is updated **automatically**. The
`update-homebrew-tap` job in `release.yml`:

1. waits for the bottle and source tarball to be present on the release tag,
2. computes both SHA256 hashes by downloading them through `curl`,
3. rewrites `Formula/ikafssn.rb` (URL, source `sha256`, bottle `root_url`,
   and `arm64_tahoe` `sha256`) via a small Python script,
4. commits and pushes the result to `main` of this repository using a
   dedicated GitHub token (`HOMEBREW_IKAFSSN_TOKEN`).

There should be no need for a maintainer to edit `Formula/ikafssn.rb` by
hand. If the formula falls out of sync (e.g., a release dispatch was
re-triggered and the build was skipped because the asset was already
present), re-dispatching the release workflow will refresh the formula.
