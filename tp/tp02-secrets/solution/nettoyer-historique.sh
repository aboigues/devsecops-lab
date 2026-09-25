#!/usr/bin/env bash
# Purge les clés AWS de TOUT l'historique du dépôt passé en argument.
# Préalable, hors script : la clé a été RÉVOQUÉE chez le fournisseur. Réécrire l'historique ne
# rend pas une clé déjà clonée inoffensive ; seule la révocation le fait.
# Usage : ./nettoyer-historique.sh <dépôt>
set -euo pipefail
cd "${1:?usage : $0 <dépôt>}"

# 1. Réécrire chaque commit : retirer les lignes aws.* et leur commentaire du fichier de configuration.
#    (En entreprise, préférer git filter-repo, plus rapide et plus sûr ; filter-branch est livré avec git.)
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --tree-filter \
  "if [ -f application.properties ]; then sed -i '/^# Clé de test/d; /^aws\.access-key-id=/d; /^aws\.secret-access-key=/d' application.properties; fi" \
  -- --all

# 2. Supprimer les références de sauvegarde créées par filter-branch (elles pointent sur l'ancien historique).
git for-each-ref --format='%(refname)' refs/original/ | xargs -r -n 1 git update-ref -d

# 3. Oublier le reflog, puis supprimer physiquement les objets devenus inaccessibles.
git reflog expire --expire=now --all
git gc --quiet --prune=now
