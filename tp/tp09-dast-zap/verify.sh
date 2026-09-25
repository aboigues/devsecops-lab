#!/usr/bin/env bash
# TP09 : vérifie qu'une application démarrée et durcie passe le DAST (ZAP baseline) sans aucune alerte,
# grâce à ses en-têtes de sécurité, et sans exception muette dans la configuration de ZAP.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require docker curl
TARGET="$(cd "$TARGET" && pwd)"

# Même image que la CI du dépôt (.github/workflows/ci.yml), épinglée par digest
ZAP="zaproxy/zap-stable:2.17.0@sha256:781a2bdaea47324e7bab583e2263f21d257b0aee61ed51521a5be45f5f5081ef"
IMG="tp09-soldes:$(basename "$TARGET")"
NAME="tp09-soldes"
NET="tp09-net"
PORT=8089
WRK="$(mktemp -d)"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  docker rmi "$IMG" >/dev/null 2>&1 || true
  rm -rf "$WRK"
}
trap cleanup EXIT
cleanup
WRK="$(mktemp -d)"

step "1) Construction et démarrage durci (non-root, lecture seule, aucune capacité)"
check_verbose "docker build réussit" docker build -q -t "$IMG" "$TARGET"
docker network create "$NET" >/dev/null
docker run -d --name "$NAME" --network "$NET" --read-only --tmpfs /tmp --cap-drop ALL \
  --security-opt no-new-privileges -p "$PORT:8080" "$IMG" >/dev/null
wait_for_http "http://localhost:$PORT/health" 40 || { docker logs "$NAME"; exit 1; }
assert_contains "L'API répond toujours (/api/comptes)" "Alice" "$(curl -fsS "http://localhost:$PORT/api/comptes")"

step "2) En-têtes de sécurité"
# Noms d'en-têtes insensibles à la casse (le serveur HTTP du JDK les réécrit) : tout en minuscules
ENTETES="$(curl -fsS -D - -o /dev/null "http://localhost:$PORT/api/comptes" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
assert_contains "X-Content-Type-Options: nosniff" "x-content-type-options: nosniff" "$ENTETES"
assert_contains "Cache-Control: no-store (des soldes ne se mettent pas en cache)" "cache-control: no-store" "$ENTETES"
assert_contains "Content-Security-Policy restrictive (default-src 'none')" "default-src 'none'" "$ENTETES"
assert_contains "Cross-Origin-Resource-Policy: same-origin" "cross-origin-resource-policy: same-origin" "$ENTETES"

step "3) Configuration ZAP : pas d'exception muette"
exceptions_ok() {
  # Pas de IGNORE ; au plus 2 règles rétrogradées en INFO, chacune précédée d'un commentaire
  ! grep -qP '^\d+\tIGNORE' "$TARGET/baseline.conf" \
    && [ "$(grep -cP '^\d+\tINFO' "$TARGET/baseline.conf" || true)" -le 2 ] \
    && awk '/^[0-9]+\tINFO/{ if (prev !~ /^#/) exit 1 } { prev = $0 }' "$TARGET/baseline.conf"
}
check "Aucune règle en IGNORE, au plus 2 en INFO, chacune justifiée" exceptions_ok

step "4) DAST : ZAP baseline contre l'application démarrée"
cp "$TARGET/baseline.conf" "$WRK/" && chmod -R 777 "$WRK"
check_verbose "ZAP baseline : aucune alerte WARN ni FAIL" \
  docker run --rm --network "$NET" -v "$WRK:/zap/wrk" "$ZAP" \
    zap-baseline.py -t "http://$NAME:8080/api/comptes" -c baseline.conf -r zap-report.html
cp "$WRK/zap-report.html" "$TARGET/zap-report.html" 2>/dev/null && info "Rapport : $TARGET/zap-report.html"

summary
