#!/usr/bin/env bash
# TP08 : vérifie des manifestes Kubernetes conformes au profil Pod Security « restricted » :
# namespace qui l'impose à l'admission, pod et conteneur durcis, ressources bornées, réseau fermé
# par défaut, et exceptions éventuelles ciblées et justifiées.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require trivy yq
NS="$TARGET/namespace.yaml"
DEP="$TARGET/deployment.yaml"
NP="$TARGET/networkpolicy.yaml"
# Expression yq évaluée sur le Deployment ; vraie (true) attendue
vrai() { [ "$(yq "$1" "$DEP" 2>/dev/null)" = true ]; }

step "1) Analyse statique (trivy config, MEDIUM et plus)"
IGNORE=()
[ -f "$TARGET/.trivyignore" ] && IGNORE=(--ignorefile "$TARGET/.trivyignore")
check_verbose "trivy config ne trouve aucun défaut MEDIUM/HIGH/CRITICAL" \
  trivy config --quiet --severity MEDIUM,HIGH,CRITICAL --exit-code 1 "${IGNORE[@]}" "$TARGET"
exceptions_justifiees() {
  [ -f "$TARGET/.trivyignore" ] || return 0
  # Seule KSV-0125 peut faire l'objet d'une exception, et elle doit être précédée d'un commentaire
  ! grep -vE '^[[:space:]]*(#|$)' "$TARGET/.trivyignore" | grep -vxq 'KSV-0125' \
    && awk '/^KSV-/{ if (prev !~ /^#/) exit 1 } { prev = $0 }' "$TARGET/.trivyignore"
}
check "Exceptions : KSV-0125 seulement, chacune justifiée par un commentaire" exceptions_justifiees

step "2) Le namespace impose le profil restricted à l'admission"
check "Label pod-security.kubernetes.io/enforce: restricted" \
  bash -c "[ \"\$(yq '.metadata.labels.\"pod-security.kubernetes.io/enforce\"' '$NS')\" = restricted ]"

step "3) Pod et conteneur durcis"
check "Jeton de compte de service non monté" vrai '.spec.template.spec.automountServiceAccountToken == false'
check "runAsNonRoot au niveau du pod" vrai '.spec.template.spec.securityContext.runAsNonRoot == true'
check "Profil seccomp RuntimeDefault" vrai '.spec.template.spec.securityContext.seccompProfile.type == "RuntimeDefault"'
check "Pas d'élévation de privilèges" vrai '[.spec.template.spec.containers[].securityContext.allowPrivilegeEscalation == false] | all'
check "Toutes les capacités retirées (drop ALL)" vrai '[.spec.template.spec.containers[].securityContext.capabilities.drop[] == "ALL"] | any'
check "Système de fichiers racine en lecture seule" vrai '[.spec.template.spec.containers[].securityContext.readOnlyRootFilesystem == true] | all'
check "Aucun conteneur privilégié" vrai '[.spec.template.spec.containers[].securityContext.privileged != true] | all'
check "Image épinglée (ni latest ni tag absent)" \
  bash -c "! yq '.spec.template.spec.containers[].image' '$DEP' | grep -Ev ':[A-Za-z0-9._-]+(@sha256:[0-9a-f]{64})?\$|@sha256:[0-9a-f]{64}\$' | grep -q . \
           && ! yq '.spec.template.spec.containers[].image' '$DEP' | grep -q ':latest'"

step "4) Ressources bornées et /tmp inscriptible"
check "Limite mémoire définie" vrai '[.spec.template.spec.containers[].resources.limits.memory != null] | all'
check "Requêtes CPU et mémoire définies" \
  vrai '[.spec.template.spec.containers[] | select((.resources.requests.cpu == null) or (.resources.requests.memory == null))] | length == 0'
check "Un volume emptyDir est monté sur /tmp" \
  vrai '([.spec.template.spec.containers[].volumeMounts[] | select(.mountPath == "/tmp")] | length) > 0'

step "5) Réseau : tout est fermé par défaut"
check "networkpolicy.yaml existe" test -s "$NP"
# (yq : « | » est plus prioritaire que « and », d'où les select() chaînés)
DENY='[select(.kind == "NetworkPolicy") | select((.spec.podSelector | length) == 0)
       | select(.spec.policyTypes | contains(["Ingress", "Egress"]))
       | select(.spec.ingress == null) | select(.spec.egress == null)] | length'
PORTS='[select(.kind == "NetworkPolicy") | .spec.ingress[]?.ports[]?.port] | unique | ((length == 1) and (.[0] == 8080))'
check "Une NetworkPolicy refuse tout par défaut (podSelector vide, Ingress et Egress)" \
  bash -c "[ \"\$(yq ea '$DENY' '$NP' 2>/dev/null)\" -ge 1 ]"
check "Les NetworkPolicy n'ouvrent que le port 8080" \
  bash -c "[ \"\$(yq ea '$PORTS' '$NP' 2>/dev/null)\" = true ]"

summary
