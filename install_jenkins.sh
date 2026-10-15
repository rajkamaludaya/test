#!/usr/bin/env bash
# Install Jenkins LTS natively on Ubuntu/Debian (no Docker), reachable only from this PC.
# Usage:  sudo ./install_jenkins.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then echo "Run with sudo: sudo $0"; exit 1; fi
if ! command -v apt-get >/dev/null; then echo "This script is for Ubuntu/Debian (apt)."; exit 1; fi

echo "== Installing Java (17 or 21), Git and C build tools"
apt-get update
JAVA_PKG=""
for p in openjdk-21-jre-headless openjdk-17-jre-headless; do
  if apt-cache show "$p" >/dev/null 2>&1; then JAVA_PKG="$p"; break; fi
done
if [ -z "$JAVA_PKG" ]; then echo "No Java 17/21 package found in apt. Install Java 17+ manually."; exit 1; fi
apt-get install -y "$JAVA_PKG" fontconfig git build-essential cmake curl
apt-get install -y cppcheck || echo "cppcheck not available; the static analysis stage will be skipped"

echo "== Adding the official Jenkins LTS repository"
KEY=/usr/share/keyrings/jenkins-keyring.gpg
# Jenkins rotates this key periodically (the 2023 key expired 2026-03-26);
# check https://www.jenkins.io/doc/book/installing/linux/ for the current one.
# Must be dearmored (binary) AND saved with a .gpg extension: apt's legacy
# `apt-key` helper (still used for Release.gpg verification on Ubuntu 20.04)
# picks armored-vs-binary handling purely from the filename extension — a
# binary key saved as .asc gets re-dearmored (into garbage) and silently
# drops the key, surfacing as a confusing NO_PUBKEY.
if ! curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | gpg --dearmor -o "$KEY"; then
  echo "Could not download/import the Jenkins repo key. Check the current key URL at"
  echo "https://www.jenkins.io/doc/book/installing/linux/ and update this script."
  exit 1
fi
echo "deb [signed-by=$KEY] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y jenkins

echo "== Restricting Jenkins to this PC only (127.0.0.1:8080)"
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<'EOF'
[Service]
Environment="JENKINS_LISTEN_ADDRESS=127.0.0.1"
# Allow builds from a local repo (file:///srv/git/...). Remove once you build from Gerrit.
Environment="JAVA_OPTS=-Djava.awt.headless=true -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true"
EOF

echo "== Creating /srv/git for local repos the jenkins user can read"
mkdir -p /srv/git
chown "${SUDO_USER:-root}":jenkins /srv/git
chmod 2775 /srv/git
systemctl daemon-reload
systemctl enable jenkins
systemctl restart jenkins

echo -n "== Waiting for Jenkins to start"
for _ in $(seq 1 60); do
  [ -f /var/lib/jenkins/secrets/initialAdminPassword ] && break
  echo -n .; sleep 3
done
echo
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
  echo "Initial admin password: $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
else
  echo "Jenkins did not start in time. Check: sudo journalctl -u jenkins -n 50"
  exit 1
fi

cat <<'EOF'

NEXT (from your Mac):
  1. ssh -L 8080:localhost:8080 <you>@<linux-pc>
  2. Open http://localhost:8080, paste the password above,
     choose "Install suggested plugins", then also install "HTML Publisher".
  3. Create your admin user.
  4. New Item -> Pipeline -> "Pipeline script from SCM" -> Git
     Repository URL: file:///srv/git/visible.git   Branch: */main   -> Save -> Build Now.

To create that repo (on the Linux PC, in the extracted folder):
  git init -b main && git add . && git commit -m "CI starter"
  git clone --bare . /srv/git/visible.git
  git remote add origin /srv/git/visible.git
  # later changes: git commit ... && git push origin main
EOF
