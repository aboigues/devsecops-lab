#!/usr/bin/env bash
# TP03 : vérifie que le SAST (Semgrep) ne signale plus d'injection SQL ET, indépendamment de l'outil,
# qu'aucune entrée malveillante n'atteint la base sous forme de SQL (contrôle fonctionnel).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require javac java semgrep

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

step "1) Le code compile"
check_verbose "javac compile CompteRepository et le contrôle" \
  javac -d "$WORK" "$TARGET"/src/fr/telemach/tp03/*.java controle/ControleInjection.java

step "2) SAST : Semgrep (règles p/java) ne signale plus rien"
check_verbose "semgrep scan --config p/java --error : aucun constat" \
  semgrep scan --config p/java --error --metrics=off --quiet "$TARGET/src"

step "3) Pas d'exception muette : tout « nosemgrep » est ciblé et justifié"
check "Chaque nosemgrep nomme la règle et donne une justification (nosemgrep: <règle> -- <raison>)" \
  bash -c "! grep -rn 'nosemgrep' '$TARGET/src' | grep -vE 'nosemgrep: *[a-z0-9._-]+ +-- +.{10,}'"

step "4) Contrôle fonctionnel : ce qui part réellement vers la base"
check_verbose "Entrées malveillantes : jamais concaténées, colonnes de tri en liste blanche" \
  java -cp "$WORK" ControleInjection

summary
