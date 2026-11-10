# TTP pkgs

Native Linux packages for TacTalaPaca software.

Repository base URL: **https://pkgs.tactalapaca.com**

Source and packaging scripts: **https://github.com/TacTalaPaca/TTP-pkgs** (public)

## Compatibility

| Format | Works on |
| --- | --- |
| `.deb` | Debian-based distributions |
| `.rpm` | Fedora-based, RHEL-based and SUSE-based distributions |
| pacman | Arch-based distributions |

RHEL 9 needs EPEL (for `libcloudproviders`). Tested on Debian 13, Fedora 45,
RHEL 9, openSUSE Tumbleweed/Leap 16, and Arch Linux. Architectures: `x86_64` /
`amd64` only.

## Install the repository

One command; it detects your distribution:

```bash
curl -fsSL https://pkgs.tactalapaca.com/setup/install.sh | sudo bash
```

Remove the repository:

```bash
curl -fsSL https://pkgs.tactalapaca.com/setup/uninstall.sh | sudo bash
```

Removing the repository does **not** uninstall installed packages. To remove
an app, use the commands in [Packages](#packages).

---

## Manual setup

Prefer to do it manually? These are the same steps.

### Debian-based

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pkgs.tactalapaca.com/keys/ttp-pkgs.asc \
  | sudo tee /etc/apt/keyrings/ttp-pkgs.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/ttp-pkgs.asc] https://pkgs.tactalapaca.com/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/ttp-pkgs.list
sudo apt update
```

Remove the repository:

```bash
sudo rm -f /etc/apt/sources.list.d/ttp-pkgs.list /etc/apt/keyrings/ttp-pkgs.asc
sudo apt update
```

### Fedora-based (DNF5)

```bash
sudo dnf config-manager addrepo --from-repofile=https://pkgs.tactalapaca.com/rpm/ttp-pkgs.repo
```

If `config-manager` is missing: `sudo dnf install -y dnf5-plugins`.

### RHEL-based (DNF4)

On RHEL-based systems, enable EPEL first (it provides `libcloudproviders`):

```bash
sudo dnf install -y epel-release
```

Then add the repository:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://pkgs.tactalapaca.com/rpm/ttp-pkgs.repo
```

Remove the repository (both DNF versions):

```bash
sudo rm -f /etc/yum.repos.d/ttp-pkgs.repo
sudo dnf clean all
```

### SUSE-based

```bash
sudo zypper addrepo -f https://pkgs.tactalapaca.com/rpm/ttp-pkgs.repo
sudo zypper --gpg-auto-import-keys refresh
```

Remove the repository:

```bash
sudo zypper removerepo ttp-pkgs
```

### Arch-based

```bash
curl -fsSL https://pkgs.tactalapaca.com/keys/ttp-pkgs.asc -o /tmp/ttp-pkgs.asc
FPR=$(gpg --with-colons --show-keys /tmp/ttp-pkgs.asc | awk -F: '/^fpr:/{print $10; exit}')
sudo pacman-key --add /tmp/ttp-pkgs.asc
sudo pacman-key --lsign-key "$FPR"
printf '\n[ttp-pkgs]\nSigLevel = Optional DatabaseRequired\nServer = https://pkgs.tactalapaca.com/arch/$arch\n' \
  | sudo tee -a /etc/pacman.conf
sudo pacman -Sy
```

Remove the repository:

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
| Package | Latest | Available versions | Formats |
| --- | --- | --- | --- |
| `firegila` | **`0.1.3`** | `0.1.3`, `0.1.2` | deb, rpm, arch |
<!-- PACKAGES:END -->

These are normal system packages. Install one with your package manager.
Replace `firegila` with the package name from the table:

```bash
sudo apt install firegila        # Debian-based
sudo dnf install firegila        # Fedora/RHEL-based
sudo zypper install firegila     # SUSE-based
sudo pacman -S firegila          # Arch-based
```

Uninstall it the same way:

```bash
sudo apt remove firegila         # Debian-based
sudo dnf remove firegila         # Fedora/RHEL-based
sudo zypper remove firegila      # SUSE-based
sudo pacman -Rns firegila        # Arch-based
```

This removes the app itself, not the repository. If you removed the repository
first, the app is still installed and can still be removed this way. The
package manager keeps its own local record of installed packages, so it does
not need the repository to uninstall them.

Updates work like any other package: run your normal system upgrade command.

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
