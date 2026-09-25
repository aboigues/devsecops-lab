#!/usr/bin/env bash
# TP04 : vérifie la gate SCA (elle laisse passer le projet sain et BLOQUE une dépendance vulnérable)
# et le SBOM (il existe, il est exploitable, il répond à « sommes-nous concernés ? »).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require mvn java trivy jq
TARGET="$(cd "$TARGET" && pwd)"

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# Version saine de référence, lue dans le projet (Dependabot peut la faire évoluer)
LOG4J="$(sed -n 's|.*<log4j.version>\(.*\)</log4j.version>.*|\1|p' projet/pom.xml)"

step "1) Projet sain : la gate passe et produit le SBOM"
cp -r projet "$WORK/sain"
check_verbose "sca.sh réussit sur le projet à jour" "$TARGET/sca.sh" "$WORK/sain"
SBOM="$WORK/sain/target/sbom.cdx.json"
check "Le SBOM target/sbom.cdx.json existe" test -s "$SBOM"
check "C'est un SBOM CycloneDX" bash -c "[ \"\$(jq -r .bomFormat '$SBOM' 2>/dev/null)\" = CycloneDX ]"
check "Il recense la dépendance transitive log4j-api (pas seulement les dépendances directes)" \
  bash -c "jq -e '.components[] | select(.name == \"log4j-api\")' '$SBOM'"

step "2) « Sommes-nous concernés ? » : interroger le SBOM"
SORTIE="$("$TARGET/concerne.sh" "$SBOM" log4j-core 2>/dev/null || true)"
assert_contains "concerne.sh log4j-core répond « log4j-core $LOG4J »" "log4j-core $LOG4J" "$SORTIE"
check_fails "concerne.sh commons-text sort en erreur (composant absent)" \
  "$TARGET/concerne.sh" "$SBOM" commons-text
check_fails "concerne.sh log4j ne confond pas avec log4j-core ni log4j-api (nom exact)" \
  "$TARGET/concerne.sh" "$SBOM" log4j

step "3) La gate BLOQUE une dépendance vulnérable (log4j-core 2.14.1, Log4Shell)"
cp -r projet "$WORK/vulnerable"
sed -i 's|<log4j.version>[^<]*</log4j.version>|<log4j.version>2.14.1</log4j.version>|' "$WORK/vulnerable/pom.xml"
check_fails "sca.sh échoue sur log4j-core 2.14.1" "$TARGET/sca.sh" "$WORK/vulnerable"
check "Le SBOM est produit même quand la gate échoue" test -s "$WORK/vulnerable/target/sbom.cdx.json"
SORTIE="$("$TARGET/concerne.sh" "$WORK/vulnerable/target/sbom.cdx.json" log4j-core 2>/dev/null || true)"
assert_contains "Le SBOM désigne la version fautive" "log4j-core 2.14.1" "$SORTIE"

summary
