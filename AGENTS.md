# AGENTS.md - TTP pkgs

## 1. Scope

- This repository builds the public package repository at https://pkgs.tactalapaca.com.
- It hosts signed deb, rpm and Arch packages.
- AppImage and tarball builds stay on the upstream GitHub release page.
- The public source repository is `TTP-pkgs`. The software names stay unchanged.

## 2. Layout

```
pkgs/<app>/<version>/   local package archive, ignored by git
repo/                       generated repository tree, ignored by git
keys/                       public signing key
scripts/                    publish, index, sign, sync and verify scripts
setup/                      install and uninstall templates
```

- `repo/` is generated. `pkgs/` is the local archive. Do not commit either.
- `README.md` is tracked and contains generated marker blocks.
- `AGENTS.md` is tracked and is the release rulebook.

## 3. Release rules

- Publish a package only after the upstream release exists and the source is committed and tagged.
- The upstream keeps only its current `dist/`. Every previous version must already be in `pkgs/<app>/<version>/`.
- Use the package files from the upstream release. Do not rebuild them in this repository.
- TTP pkgs hosts only `.deb`, `.rpm` and `.pkg.tar.zst` files.
- Keep every version in `pkgs/`. The published repo also keeps every version by default. Set `KEEP_VERSIONS` to a positive number to prune.
- Never hand edit the package table in `README.md`.
- The table between `<!-- PACKAGES:START -->` and `<!-- PACKAGES:END -->` is generated from `repo/` by `scripts/gen-readme.sh`.
- The key block between `<!-- KEY:START -->` and `<!-- KEY:END -->` is generated too.
- The README package row must show the new upstream version after publishing. If it does not, the publish step did not complete.
- Sign every published package and index. Use `--unsigned` only for a local test and never for a live sync.

## 4. Publish a new version

Example for Firegila 1.1:

```sh
cd /home/danuja/TacTalaPaca/TTP-pkgs

# 1. Place the release packages in the ignored drop directory.
install -d pkgs/firegila/1.1
cp /home/danuja/TacTalaPaca/Code/TTP-Browser/dist/firegila_1.1_amd64.deb \
   /home/danuja/TacTalaPaca/Code/TTP-Browser/dist/firegila-1.1-1.x86_64.rpm \
   /home/danuja/TacTalaPaca/Code/TTP-Browser/dist/firegila-1.1-1-x86_64.pkg.tar.zst \
   pkgs/firegila/1.1/

# 2. Unlock the signing key for this session.
./scripts/unlock-key.sh

# 3. Rebuild indexes, sign metadata, prune old versions and regenerate README.
./scripts/publish.sh pkgs/firegila/1.1

# 4. Verify metadata, signatures and README output.
./scripts/verify.sh
grep -A 4 'PACKAGES:START' README.md

# 5. Upload the verified tree to the live repository.
./scripts/sync-r2.sh
```

- `publish.sh --sync` does the publish and upload in one run. Prefer the separate verify step before a live upload.
- If the signing key is not available, stop. Do not sync an unsigned tree.
- After publishing, the README table must show the new version as latest.
- Example expected row for Firegila 1.1 with two versions kept:

```
| `firegila` | **`1.1`** | `1.1`, `0.1.3` | deb, rpm, arch |
```

## 5. Pruning

- `publish.sh` prunes only when `KEEP_VERSIONS` is greater than 0. The default 0 keeps every version.
- To inspect before deleting:

```sh
./scripts/prune.sh --all --keep 2
```

- To prune the local drop and the published tree:

```sh
./scripts/prune.sh --all --keep 2 --yes
```

- Do not remove a version that is still referenced by a supported release or a user pin.

## 6. Verification

- `./scripts/verify.sh` must pass.
- Check the generated README row.
- Check that `repo/apt`, `repo/rpm` and `repo/arch` contain the new files and refreshed indexes.
- Check that signatures exist for APT `InRelease`, RPM `repomd.xml` and Arch databases.
- Check that `repo/arch/*/ttp-pkgs.db` is a real file, not a symlink.
- Only then run `sync-r2.sh`.

## 7. Git

- Commit only tracked files such as `README.md`, `AGENTS.md`, `scripts/`, `setup/` and `keys/ttp-pkgs.asc`.
- Do not commit `repo/`, `pkgs/`, `.tmp/`, logs or private keys.
- Keep commit subjects short and mechanical.
- Do not rewrite history without owner approval.
- Do not push until the owner approves.

## 8. Upstream release checklist

For every new Firegila release:

1. Build and publish the upstream GitHub release first.
2. Confirm the upstream release commit and tag match the package version.
3. Copy only the deb, rpm and Arch package into `pkgs/firegila/<version>/`.
4. Run the publish and verify steps above.
5. Confirm the README Firegila row shows the new version.
6. Sync to R2 only after verification.
