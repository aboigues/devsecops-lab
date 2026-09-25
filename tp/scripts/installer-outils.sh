#!/usr/bin/env bash
# Installe les outils de sécurité des TP, aux versions utilisées par la CI du dépôt.
# Linux x86_64 (dont WSL2). Les binaires sont vérifiés par empreinte SHA-256 avant installation :
# une archive modifiée en route (miroir compromis, proxy) est refusée.
#
# Usage : tp/scripts/installer-outils.sh            -> installe dans ~/.local/bin
#         TP_BIN=/chemin tp/scripts/installer-outils.sh
set -euo pipefail

TRIVY_VERSION=0.74.0
TRIVY_SHA256=2ae6fe3ee734b7fdf11335663e18c75ea12dccc76062f09f164a3b0f8be4371a
GITLEAKS_VERSION=8.30.1
GITLEAKS_SHA256=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
SEMGREP_VERSION=1.178.0
ZIZMOR_VERSION=1.30.1

BIN="${TP_BIN:-$HOME/.local/bin}"
VENV="${TP_VENV:-$HOME/.local/share/devsecops-tp/venv}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$BIN"

if [ "$(uname -s)-$(uname -m)" != "Linux-x86_64" ]; then
  echo "Ce script vise Linux x86_64. Ailleurs, installer les mêmes versions à la main :"
  echo "trivy $TRIVY_VERSION, gitleaks $GITLEAKS_VERSION, semgrep $SEMGREP_VERSION, zizmor $ZIZMOR_VERSION"
  exit 1
fi

install_tarball() { # nom url sha256
  local name="$1" url="$2" sha="$3"
  echo ">> $name"
  curl -fsSL -o "$TMP/$name.tar.gz" "$url"
  echo "$sha  $TMP/$name.tar.gz" | sha256sum -c --quiet -
  tar -xzf "$TMP/$name.tar.gz" -C "$TMP" "$name"
  install -m 0755 "$TMP/$name" "$BIN/$name"
}

install_tarball trivy \
  "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
  "$TRIVY_SHA256"
install_tarball gitleaks \
  "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  "$GITLEAKS_SHA256"

echo ">> semgrep et zizmor (environnement Python isolé)"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --disable-pip-version-check \
  "semgrep==${SEMGREP_VERSION}" "zizmor==${ZIZMOR_VERSION}"
ln -sf "$VENV/bin/semgrep" "$BIN/semgrep"
ln -sf "$VENV/bin/zizmor" "$BIN/zizmor"

echo
"$BIN/trivy" --version | head -1
echo "gitleaks $("$BIN/gitleaks" version)"
echo "semgrep $("$BIN/semgrep" --version)"
"$BIN/zizmor" --version
case ":$PATH:" in *":$BIN:"*) ;; *) echo "Penser à ajouter $BIN au PATH." ;; esac
