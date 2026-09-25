#!/usr/bin/env bash
# TP05 : vérifie qu'une image est durcie : Dockerfile conforme (trivy config), bases épinglées par
# digest, multi-stage (ni compilateur ni sources livrés), non-root, sans vulnérabilité HIGH/CRITICAL
# corrigeable, et toujours fonctionnelle avec un système de fichiers en lecture seule.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require docker trivy curl

IMG="tp05-soldes:$(basename "$TARGET")"
NAME="tp05-soldes-run"
PORT=8085

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker rmi "$IMG" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

step "1) Dockerfile : analyse statique (trivy config, MEDIUM et plus)"
check_verbose "trivy config ne trouve aucun défaut MEDIUM/HIGH/CRITICAL" \
  trivy config --quiet --severity MEDIUM,HIGH,CRITICAL --exit-code 1 "$TARGET"
check "Chaque FROM est épinglé par digest (@sha256:)" \
  bash -c "! grep -iE '^FROM ' '$TARGET/Dockerfile' | grep -v '@sha256:'"
check "Build multi-stage (au moins deux FROM)" \
  bash -c "[ \"\$(grep -ciE '^FROM ' '$TARGET/Dockerfile')\" -ge 2 ]"
check "Un .dockerignore limite le contexte de build" test -s "$TARGET/.dockerignore"

step "2) Construction"
check_verbose "docker build réussit" docker build -q -t "$IMG" "$TARGET"

step "3) Contenu de l'image finale"
UCFG="$(docker image inspect "$IMG" --format '{{.Config.User}}' 2>/dev/null || true)"
info "Config.User = '${UCFG:-<vide>}'"
check "L'image ne tourne pas en root" \
  bash -c "[ -n '$UCFG' ] && [ '${UCFG%%:*}' != root ] && [ '${UCFG%%:*}' != 0 ]"
check_fails "Pas de compilateur livré (javac absent)" docker run --rm --entrypoint javac "$IMG" -version
check "Ni code source ni Dockerfile dans l'image" \
  bash -c "[ -z \"\$(docker run --rm --entrypoint find '$IMG' / -xdev \( -name Main.java -o -name Dockerfile \) 2>/dev/null)\" ]"

step "4) Scan de l'image (OS + JRE) : aucune HIGH/CRITICAL corrigeable"
check_verbose "trivy image ne trouve aucune vulnérabilité HIGH/CRITICAL corrigeable" \
  trivy image --quiet --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$IMG"

step "5) L'image durcie fonctionne sous contraintes (comme dans Kubernetes)"
docker run -d --name "$NAME" --read-only --tmpfs /tmp --cap-drop ALL \
  --security-opt no-new-privileges -p "$PORT:8080" "$IMG" >/dev/null 2>&1 || true
if wait_for_http "http://localhost:$PORT/health" 40; then
  assert_contains "/health répond ok (lecture seule, aucune capacité)" "ok" \
    "$(curl -fsS "http://localhost:$PORT/health")"
else
  docker logs "$NAME" 2>&1 | tail -n 20 || true
  check "/health répond ok (lecture seule, aucune capacité)" false
fi

summary
