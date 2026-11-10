# TTP-pkgs — setup plan

Current state and remaining work, updated after the rename to TTP-pkgs on 2026-11-10.

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

## Remaining

1. [ ] Create the signing key — `./scripts/init-key.sh`
       (agent runs it; you enter the passphrase in the pinentry popup)
2. [ ] Cloudflare: create R2 bucket `ttp-pkgs` — agent
3. [ ] Cloudflare: connect custom domain `pkgs.tactalapaca.com` — agent
4. [ ] Cloudflare: verify DNS record and TLS status — agent
5. [ ] Create an R2 API token: Object Read & Write, bucket `ttp-pkgs` — **you**
6. [ ] Configure rclone — `./scripts/init-r2.sh` — **you**
7. [ ] Copy Firegila 0.1.3 into `packages/firegila/0.1.3/` — agent
8. [ ] Publish — `./scripts/publish.sh --sync` — agent
9. [ ] Verify — `./scripts/verify.sh` + `curl` the public URLs — agent
10. [ ] Install `github-cli` (agent, sudo popup), then `gh auth login` — **you**
11. [ ] Create the public GitHub repo `TTP-pkgs` and push — agent
12. [ ] Optional: landing page at `https://pkgs.tactalapaca.com/`
13. [ ] Optional: distrobox end-to-end test (`apt` / `dnf` / `pacman`)

## Notes

- `tactalapaca.com` and `www` stay on Cloudflare Pages; only the `pkgs` subdomain is added.
- The Cloudflare MCP session has R2 + DNS edit, but **no API Tokens Write**, so the
  rclone token is created manually in the dashboard.
- Secrets never live in this repository: the private GPG key stays in `~/.gnupg`,
  the R2 secret stays in `~/.config/rclone/rclone.conf` (mode 600).
- R2 free tier: 10 GB-month, free egress. Use `./scripts/prune.sh <package> <keep>`
  to drop old versions.
