#!/usr/bin/env bash
# TP07 : vérifie que le workflow d'accueil n'est plus exploitable (zizmor, profil auditor) tout en
# rendant toujours le même service : remercier l'auteur d'une nouvelle PR en citant son titre.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require zizmor yq
WF="$TARGET/workflows/accueil.yml"

step "1) Le workflow est un YAML valide"
check_verbose "yq lit le workflow" yq -e '.jobs' "$WF"

step "2) Analyse statique de la CI : zizmor (profil auditor, sévérité moyenne et plus)"
check_verbose "zizmor ne trouve aucun constat de sévérité moyenne ou haute" \
  zizmor --offline --no-progress --persona auditor --min-severity medium "$WF"

step "3) Contrôles ciblés"
check "Déclencheur pull_request_target abandonné" \
  bash -c "[ \"\$(yq '.on | has(\"pull_request_target\")' '$WF')\" = false ]"
check "Aucune expression \${{ }} dans un script run:" \
  bash -c "! yq '.. | select(has(\"run\")) | .run' '$WF' | grep -q '\${{'"
check "Toute action est épinglée par SHA de commit complet (40 caractères)" \
  bash -c "! yq '.. | select(has(\"uses\")) | .uses' '$WF' | grep -vE '@[0-9a-f]{40}\$'"
check "Permissions du workflow vides (permissions: {})" \
  bash -c "[ \"\$(yq -o=json '.permissions' '$WF')\" = '{}' ]"

step "4) Le service rendu est intact"
check "Le workflow réagit toujours à l'ouverture d'une PR" \
  bash -c "[ \"\$(yq '.on.pull_request.types[]' '$WF' 2>/dev/null)\" = opened ]"
check "Le titre de la PR est toujours cité, via une variable d'environnement" \
  bash -c "yq '.. | select(has(\"env\")) | .env[]' '$WF' | grep -q 'github.event.pull_request.title'"

summary
