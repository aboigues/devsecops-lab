#!/usr/bin/env bash
# « Sommes-nous concernés ? » : cherche un composant dans un SBOM CycloneDX.
# Affiche « <nom> <version> » pour chaque composant dont le nom correspond exactement ;
# code de sortie 1 si aucun ne correspond.
# Usage : ./concerne.sh <sbom.cdx.json> <nom du composant>   ex. : ./concerne.sh sbom.cdx.json log4j-core
set -euo pipefail
SBOM="${1:?usage : $0 <sbom> <composant>}"
NOM="${2:?usage : $0 <sbom> <composant>}"

# TODO 3 : avec jq, parcourir .components[] du SBOM, garder ceux dont .name vaut "$NOM",
#          afficher « nom version », et sortir en erreur si la liste est vide.
echo "concerne.sh : pas encore implémenté" >&2
exit 1
