# TTP pkgs

Native Linux packages for TacTalaPaca software.

Repository base URL: **https://pkgs.tactalapaca.com**

Source and packaging scripts: **https://github.com/TacTalaPaca/TTP-pkgs** (public)

Supported: Debian/Ubuntu (`.deb`), Fedora/RHEL/openSUSE (`.rpm`), Arch
(`.pkg.tar.zst`). Architectures: `x86_64` / `amd64`.

## Install the repository

One command; it detects your distribution:

```bash
curl -fsSL https://pkgs.tactalapaca.com/setup/install.sh | sudo bash
```

Remove it:

```bash
curl -fsSL https://pkgs.tactalapaca.com/setup/uninstall.sh | sudo bash
```

Removing the repository does **not** uninstall software that came from it.

---

## Manual setup

Prefer to do it manually? These are the same steps.

### Debian / Ubuntu / Mint / Pop!_OS

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pkgs.tactalapaca.com/keys/ttp-pkgs.asc \
  | sudo tee /etc/apt/keyrings/ttp-pkgs.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/ttp-pkgs.asc] https://pkgs.tactalapaca.com/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/ttp-pkgs.list
sudo apt update
```

Remove:

```bash
sudo rm -f /etc/apt/sources.list.d/ttp-pkgs.list /etc/apt/keyrings/ttp-pkgs.asc
sudo apt update
```

### Fedora (DNF5)

```bash
sudo dnf config-manager addrepo --from-repofile=https://pkgs.tactalapaca.com/rpm/ttp-pkgs.repo
```

If `config-manager` is missing: `sudo dnf install -y dnf5-plugins`.

### RHEL / Rocky / AlmaLinux (DNF4)

On RHEL 9 / AlmaLinux 9 / Rocky 9, enable EPEL first (it provides
`libcloudproviders`):

```bash
sudo dnf install -y epel-release
```

Then add the repository:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://pkgs.tactalapaca.com/rpm/ttp-pkgs.repo
```

Remove (both DNF versions):

```bash
sudo rm -f /etc/yum.repos.d/ttp-pkgs.repo
sudo dnf clean all
```

### openSUSE / SLES

```bash
sudo zypper addrepo -f https://pkgs.tactalapaca.com/rpm/ttp-pkgs.repo
sudo zypper --gpg-auto-import-keys refresh
```

Remove:

```bash
sudo zypper removerepo ttp-pkgs
```

### Arch / EndeavourOS / Manjaro

```bash
curl -fsSL https://pkgs.tactalapaca.com/keys/ttp-pkgs.asc -o /tmp/ttp-pkgs.asc
FPR=$(gpg --with-colons --show-keys /tmp/ttp-pkgs.asc | awk -F: '/^fpr:/{print $10; exit}')
sudo pacman-key --add /tmp/ttp-pkgs.asc
sudo pacman-key --lsign-key "$FPR"
printf '\n[ttp-pkgs]\nSigLevel = Optional DatabaseRequired\nServer = https://pkgs.tactalapaca.com/arch/$arch\n' \
  | sudo tee -a /etc/pacman.conf
sudo pacman -Sy
```

Remove:

```bash
FPR=$(curl -fsSL https://pkgs.tactalapaca.com/keys/ttp-pkgs.asc \
  | gpg --with-colons --show-keys | awk -F: '/^fpr:/{print $10; exit}')
sudo pacman-key --delete "$FPR" 2>/dev/null || true
sudo sed -i '/^\[ttp-pkgs\]/,/^$/d' /etc/pacman.conf
sudo pacman -Sy
```

---

## Packages

<!-- PACKAGES:START -->
| Package | Latest version | Formats |
| --- | --- | --- |
| `firegila` | `0.1.3` | deb, rpm, arch |
<!-- PACKAGES:END -->

---

## Signing key

<!-- KEY:START -->
Signing key fingerprint: `49E649426C9D967D67CAC995CEF97BF527E017C9`

```bash
curl -fsSL https://pkgs.tactalapaca.com/keys/ttp-pkgs.asc | gpg --show-keys --with-fingerprint
```
<!-- KEY:END -->

The indexes are signed with this key. RPM packages are also signed
individually.

---

## Uninstalling packages

Use your package manager:

```bash
sudo apt purge <package>       # Debian/Ubuntu
sudo dnf remove <package>      # Fedora/RHEL
sudo zypper remove <package>   # openSUSE
sudo pacman -Rns <package>     # Arch
```
