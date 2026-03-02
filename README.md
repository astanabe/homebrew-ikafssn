# homebrew-ikafssn

Homebrew tap for [ikafssn](https://github.com/astanabe/ikafssn).

## Installation

```
brew tap astanabe/ikafssn
brew install ikafssn
```

## Updating the formula (for maintainers)

After creating a new release on GitHub (tag format: `vX.Y.YYYY.MM.DD`):

1. Wait for the GitHub Actions workflow to complete (builds .deb and Bottle).

2. Compute SHA256 hashes:

   ```
   VERSION="0.1.YYYY.MM.DD"
   TAG="v${VERSION}"
   curl -sL "https://github.com/astanabe/ikafssn/archive/refs/tags/${TAG}.tar.gz" | sha256sum
   curl -sL "https://github.com/astanabe/ikafssn/releases/download/${TAG}/ikafssn-${VERSION}.arm64_tahoe.bottle.tar.gz" | sha256sum
   ```

   The Bottle SHA256 is also printed in the CI log as a `::notice::` annotation.

3. Edit `Formula/ikafssn.rb`:
   - Update the `url` tag (e.g., `v0.1.2026.02.28`)
   - Update the source `sha256`
   - Update `root_url` and `sha256` (`arm64_tahoe`) in the `bottle do` block

4. Commit and push:

   ```
   git add Formula/ikafssn.rb
   git commit -m "Update ikafssn formula to ${VERSION}"
   git push
   ```
