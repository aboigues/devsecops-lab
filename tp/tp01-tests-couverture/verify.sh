#!/usr/bin/env bash
# TP01 : vérifie que les tests passent, que la gate de couverture (80 %) est franchie,
# et surtout que les tests DÉTECTENT des régressions (mutants injectés un par un).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require mvn java

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

step "0) Environnement"
JAVA_MAJOR="$(java -XshowSettings:properties -version 2>&1 | awk -F' = ' '/java.specification.version/ {print $2}')"
info "Java $JAVA_MAJOR"
check "JDK 25 ou plus (le projet compile en release 25)" bash -c "[ '${JAVA_MAJOR:-0}' -ge 25 ]"

step "1) Build complet : tests + rapport + gate de couverture (mvn verify)"
cp -r "$TARGET" "$WORK/projet"
check_verbose "mvn verify réussit (tests verts, couverture lignes et branches >= 80 %)" \
  mvn -B -q -f "$WORK/projet/pom.xml" verify

step "2) Des tests en nombre suffisant"
NB_TESTS="$(cat "$WORK"/projet/target/surefire-reports/TEST-*.xml 2>/dev/null \
  | grep -o '<testcase ' | wc -l || true)"
info "tests exécutés : $NB_TESTS"
check "Au moins 8 cas de test exécutés" bash -c "[ '${NB_TESTS:-0}' -ge 8 ]"

step "3) La gate de couverture n'a pas été affaiblie"
check "pom.xml : seuil jacoco toujours à 0.80 (lignes et branches)" \
  bash -c "[ \"\$(grep -c '<minimum>0.80</minimum>' '$TARGET/pom.xml')\" -ge 2 ]"

step "4) Les tests détectent les régressions (tests de mutation)"
for mutant in mutants/*.java; do
  nom="$(basename "$mutant" .java)"
  rm -rf "$WORK/mutant" && cp -r "$TARGET" "$WORK/mutant"
  cp "$mutant" "$WORK/mutant/src/main/java/fr/telemach/tp01/ServiceVirement.java"
  check_fails "Mutant « $nom » : au moins un test échoue" \
    mvn -B -q -f "$WORK/mutant/pom.xml" test
done

summary
