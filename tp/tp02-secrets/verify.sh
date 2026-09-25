#!/usr/bin/env bash
# TP02 : vérifie que la clé AWS a disparu de TOUT l'historique (pas seulement du fichier courant),
# sans perdre le reste du travail, et que le hook pre-commit bloque un nouveau secret.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require git gitleaks
TARGET="$(cd "$TARGET" && pwd)"

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
DEPOT="$WORK/depot"

step "1) Dépôt de Léa : la clé a été « supprimée » au dernier commit"
./creer-depot.sh "$DEPOT" >/dev/null
CLE="$(git -C "$DEPOT" show HEAD~1:application.properties | sed -n 's/^aws.access-key-id=//p')"
check "Le fichier courant est propre (gitleaks dir)" gitleaks dir "$DEPOT" --no-banner --exit-code 1
check_fails "Mais l'historique contient la clé (gitleaks git)" \
  gitleaks git "$DEPOT" --no-banner --exit-code 1

step "2) Purge de l'historique par votre script"
check_verbose "nettoyer-historique.sh s'exécute sans erreur" "$TARGET/nettoyer-historique.sh" "$DEPOT"

step "3) La clé a disparu de l'historique ET des objets git"
check "gitleaks git ne trouve plus rien" gitleaks git "$DEPOT" --no-banner --exit-code 1
check "La clé n'apparaît dans aucun commit (git log -p --all)" \
  bash -c "! git -C '$DEPOT' log -p --all | grep -q '$CLE'"
check "La clé n'existe plus dans aucun objet, même inaccessible" \
  bash -c "! git -C '$DEPOT' cat-file --batch-all-objects --batch | grep -aq '$CLE'"

step "4) Le reste du travail est intact"
NB="$(git -C "$DEPOT" rev-list --count HEAD 2>/dev/null || echo 0)"
info "commits : $NB"
check "Les 3 commits sont conservés" bash -c "[ '$NB' -eq 3 ]"
check "La configuration utile est toujours là (bucket d'exports)" \
  bash -c "git -C '$DEPOT' show HEAD:application.properties | grep -q '^bank.exports.bucket='"
check "Le commit « lecture des exports » a gardé sa configuration" \
  bash -c "git -C '$DEPOT' show HEAD~1:application.properties | grep -q '^server.port=8080'"

step "5) Le hook pre-commit bloque un nouveau secret"
install -m 0755 "$TARGET/pre-commit" "$DEPOT/.git/hooks/pre-commit"
NOUVELLE="AKIA$(LC_ALL=C tr -dc 'A-Z2-7' </dev/urandom | head -c 16 || true)"
echo "aws.access-key-id=$NOUVELLE" >> "$DEPOT/application.properties"
git -C "$DEPOT" add application.properties
check_fails "Un commit contenant une clé AWS est refusé" git -C "$DEPOT" commit -q -m "test: clé"
git -C "$DEPOT" checkout -q HEAD -- application.properties
echo "server.shutdown=graceful" >> "$DEPOT/application.properties"
git -C "$DEPOT" add application.properties
check "Un commit sans secret passe" git -C "$DEPOT" commit -q -m "feat: arrêt gracieux"

summary
