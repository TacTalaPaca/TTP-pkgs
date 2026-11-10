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
- [x] Cloudflare R2 bucket `ttp-pkgs` created (EEUR, Standard)
- [x] Custom domain `pkgs.tactalapaca.com` connected — SSL active, ownership active, minTLS 1.2
- [x] DNS before/after diff: only new CNAME `pkgs` → `public.r2.dev`; apex/www/MX/TXT unchanged
- [x] `r2.dev` public development URL left disabled (custom domain only)
- [x] Uploads set `Cache-Control: no-cache` at the object level (no zone-wide rules)
- [x] Signing key created: `49E649426C9D967D67CAC995CEF97BF527E017C9`
- [x] R2 API token created (Object Read & Write, bucket `ttp-pkgs`)
- [x] rclone remote `ttp-pkgs:` configured and verified

## Remaining

1. [ ] Copy Firegila 0.1.3 into `packages/firegila/0.1.3/` — agent
2. [ ] Publish — `./scripts/publish.sh --sync` — agent
3. [ ] Verify — `./scripts/verify.sh` + `curl` the public URLs — agent
4. [ ] Install `github-cli` (agent, sudo popup), then `gh auth login` — **you**
5. [ ] Create the public GitHub repo `TTP-pkgs` and push — agent
6. [ ] Optional: distrobox end-to-end test (`apt` / `dnf` / `pacman`)
7. [ ] Optional (later): landing page at `https://pkgs.tactalapaca.com/`

## Notes

- `tactalapaca.com` and `www` stay on Cloudflare Pages; only the `pkgs` subdomain is added.
- The Cloudflare MCP session has R2 + DNS edit, but **no API Tokens Write**, so the
  rclone token is created manually in the dashboard.
- Secrets never live in this repository: the private GPG key stays in `~/.gnupg`,
  the R2 secret stays in `~/.config/rclone/rclone.conf` (mode 600).
- R2 free tier: 10 GB-month, free egress. Use `./scripts/prune.sh <package> <keep>`
  to drop old versions.
