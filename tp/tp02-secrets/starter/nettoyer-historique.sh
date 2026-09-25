#!/usr/bin/env bash
# Purge les clés AWS de TOUT l'historique du dépôt passé en argument.
# Préalable, hors script : la clé a été RÉVOQUÉE chez le fournisseur.
# Usage : ./nettoyer-historique.sh <dépôt>
set -euo pipefail
cd "${1:?usage : $0 <dépôt>}"

# TODO 1 : réécrire TOUS les commits (toutes les branches) pour retirer du fichier
#          application.properties les lignes aws.access-key-id, aws.secret-access-key
#          et le commentaire qui les précède. Les autres lignes et les 3 commits sont conservés.
#          Outil livré avec git : git filter-branch --tree-filter "<commande>" -- --all

# TODO 2 : supprimer les références de sauvegarde laissées par filter-branch (refs/original/).

# TODO 3 : vider le reflog et supprimer physiquement les objets inaccessibles
#          (sinon la clé reste lisible avec git cat-file).

echo "nettoyer-historique.sh : pas encore implémenté" >&2
exit 1
