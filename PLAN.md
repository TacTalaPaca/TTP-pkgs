# TTP-pkgs — setup plan

Status, verification and maintenance notes.

## Naming

| Thing | Value |
|---|---|
| Local folder | `/home/danuja/TacTalaPaca/TTP-pkgs` |
| GitHub repository | `TacTalaPaca/TTP-pkgs` — **public** |
| Cloudflare R2 bucket | `ttp-pkgs` |
| Public base URL | `https://pkgs.tactalapaca.com` |
| pacman repository | `ttp-pkgs` |
| RPM repo id / file | `ttp-pkgs` / `ttp-pkgs.repo` |
| APT suite / component | `stable` / `main` |
| Signing key file | `keys/ttp-pkgs.asc` |

## Done

- [x] Repository framework: `publish.sh`, apt/rpm/pacman indexers, `verify.sh`, `prune.sh`
- [x] Per-distro `install.sh` / `uninstall.sh` templates
- [x] Full local test with a throwaway key: indexes, signatures, multi-version, prune
- [x] Renamed everything to TTP-pkgs / `pkgs.tactalapaca.com`
- [x] Cloudflare R2 bucket `ttp-pkgs` created (EEUR, Standard)
- [x] Custom domain `pkgs.tactalapaca.com` connected — SSL active, ownership active, minTLS 1.2
- [x] DNS before/after diff: only new CNAME `pkgs` → `public.r2.dev`; apex/www/MX/TXT unchanged
- [x] `r2.dev` public development URL left disabled (custom domain only)
- [x] Uploads set `Cache-Control: no-cache` at the object level (no zone-wide rules)
- [x] Signing key created: `49E649426C9D967D67CAC995CEF97BF527E017C9`
- [x] R2 API token created (Object Read & Write, bucket `ttp-pkgs`)
- [x] rclone remote `ttp-pkgs:` configured and verified
- [x] Firegila 0.1.3 published (`deb`, `rpm`, `pacman`)
- [x] Fixed Firegila Arch deps: `libgbm` -> `mesa`, dropped `at-spi2-atk`
- [x] Real-client tests: Debian 13, Fedora 45, RHEL 9 (EPEL), openSUSE Tumbleweed/Leap 16, Arch Linux
- [x] Public GitHub repo `TacTalaPaca/TTP-pkgs` created and pushed
- [x] Retention: all versions in `packages/`, newest `KEEP_VERSIONS=2` in the repo
- [x] README: compatibility table and install/remove examples in Packages

## Verified

- Debian 13: `apt-get update`, `apt-cache policy`, `apt-get download`, `apt-get install -s`
- Fedora 45: key auto-import, `dnf download --resolve` (286 packages)
- RHEL 9: resolves fully with EPEL (195 packages)
- openSUSE Tumbleweed: 107 packages resolve
- openSUSE Leap 16: 103 packages resolve
- Arch: `pacman -Si`, `pacman -Sp` (105 packages), `pacman -Sw`
- Live signatures: APT `InRelease`, RPM `repomd.xml`, pacman `ttp-pkgs.db`
- `Cache-Control: no-cache`, `cf-cache-status: DYNAMIC`
- Main site: apex `200`, `www` `301` -> apex (unchanged)

## Maintenance

- New release: copy the `.deb`, `.rpm` and `.pkg.tar.zst` into
  `packages/<app>/<version>/` (local only, gitignored), then run
  `./scripts/publish.sh --sync`. The repo keeps the newest `KEEP_VERSIONS`
  (default 2); older files stay in `packages/`.
- After a reboot the GPG cache is gone: run `./scripts/unlock-key.sh` once
  before publishing.
- Prune old versions: `./scripts/prune.sh <app> <keep>` then publish.
- Health check: `./scripts/verify.sh`.

## Remaining

1. [ ] Optional (later): landing page at `https://pkgs.tactalapaca.com/`

## Notes

- `tactalapaca.com` and `www` stay on Cloudflare Pages; only `pkgs` is added.
- Secrets stay outside the repo: the private GPG key in `~/.gnupg`, the R2 secret
  in `~/.config/rclone/rclone.conf` (mode 600).
- R2 free tier: 10 GB-month, free egress.
- One RPM serves Fedora, RHEL and openSUSE; its dependencies are sonames, not
  distro-specific package names.
