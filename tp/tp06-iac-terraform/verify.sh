#!/usr/bin/env bash
# TP06 : vérifie le module Terraform : formaté, valide, SSH jamais ouvert au monde, entrée refusée par
# défaut, bucket privé et versionné. Vos tests ET les contrôles du formateur (controles/) sont exécutés
# par « terraform test », hors ligne (fournisseur simulé : aucun appel à Scaleway, aucun coût).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-starter}"
[ -d "$TARGET" ] || { echo "Dossier introuvable : $TARGET"; exit 2; }
require terraform

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
cp -r "$TARGET" "$WORK/module"
rm -rf "$WORK/module/.terraform" "$WORK/module/.terraform.lock.hcl"
TF=(terraform -chdir="$WORK/module")

step "1) Forme et validité"
check_verbose "terraform fmt -check : code formaté" terraform fmt -check -recursive "$TARGET"
check_verbose "terraform init (sans backend)" "${TF[@]}" init -backend=false -input=false
check_verbose "terraform validate" "${TF[@]}" validate

step "2) admin_cidrs : l'ouverture SSH est un choix explicite"
bloc_admin() { awk '/^variable "admin_cidrs"/,/^}/' "$TARGET/variables.tf" | grep -v '^[[:space:]]*#'; }
sans_defaut() { ! bloc_admin | grep -qE '^[[:space:]]*default[[:space:]]*='; }
avec_validation() { bloc_admin | grep -qE '^[[:space:]]*validation[[:space:]]*\{'; }
check "admin_cidrs n'a pas de valeur par défaut" sans_defaut
check "admin_cidrs a un bloc validation" avec_validation

step "3) Vos tests (tests/securite.tftest.hcl)"
NB_RUN="$(grep -cE '^run "' "$TARGET/tests/securite.tftest.hcl" || true)"
info "blocs run : $NB_RUN"
check "Au moins 3 blocs run" bash -c "[ '${NB_RUN:-0}' -ge 3 ]"
check "Au moins un test prouve qu'une valeur interdite est refusée (expect_failures)" \
  grep -qE '^[[:space:]]*expect_failures[[:space:]]*=' "$TARGET/tests/securite.tftest.hcl"
check_verbose "terraform test : vos tests passent" \
  "${TF[@]}" test -filter=tests/securite.tftest.hcl

step "4) Contrôles du formateur (controles/controles.tftest.hcl)"
cp controles/controles.tftest.hcl "$WORK/module/tests/"
check_verbose "terraform test : entrée drop, SSH limité, bucket privé et versionné, 0.0.0.0/0 et ::/0 refusés" \
  "${TF[@]}" test -filter=tests/controles.tftest.hcl

summary
