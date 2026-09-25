#!/usr/bin/env bash
# Liste les images de conteneurs à scanner, sous forme de matrice JSON pour GitHub Actions.
# Les listes sont tirées des vraies sources (Dockerfiles, chart Helm à la version fixée dans
# Terraform, fichiers de pipeline) : une image ajoutée ou montée de version est scannée sans
# liste à maintenir à la main.
#
# Trois familles, trois politiques (voir .github/workflows/scan-images.yml) :
#   construite : images que ce dépôt construit          -> bloquant, toutes vulnérabilités corrigeables
#   deployee   : images tierces déployées par le lab    -> bloquant, paquets OS corrigeables
#   outil      : images d'outils des pipelines           -> informatif (onglet Security, résumé)
#
# Usage : .github/scripts/lister-images.sh          -> matrice JSON compacte
#         .github/scripts/lister-images.sh --lisible -> une ligne par image
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
LISTE="$(mktemp)"
trap 'rm -f "$LISTE"' EXIT

ligne() { # famille image contexte
  jq -cn --arg f "$1" --arg i "$2" --arg c "${3:-}" \
    '{famille: $f, image: $i, contexte: $c, slug: ($f + "-" + ($i | gsub("[^A-Za-z0-9._-]"; "-")))}'
}

{
  # 1. Construites ici : l'API bancaire et l'image durcie du TP05 (le TP09 part de la même base).
  ligne construite bank-api:scan app
  ligne construite soldes:scan tp/tp05-image-durcie/solution

  # 2. Déployées par le lab : images du chart Argo CD, à la version fixée dans terraform/labs et avec
  #    les mêmes valeurs que le déploiement (surcharges d'images, composants désactivés).
  CHART="$(sed -n '/variable "argocd_chart_version"/,/^}/s/.*default *= *"\(.*\)".*/\1/p' terraform/labs/variables.tf)"
  [ -n "$CHART" ] || { echo "Version du chart Argo CD introuvable dans terraform/labs/variables.tf" >&2; exit 1; }
  helm template argocd argo-cd --repo https://argoproj.github.io/argo-helm --version "$CHART" \
      --values terraform/labs/argocd-values.yaml \
    | grep -oE 'image: *"?[^" ]+' | sed -E 's/image: *"?//' | sort -u \
    | while read -r img; do ligne deployee "$img"; done

  # 3. Outils des pipelines (GitLab, Bitbucket, Jenkins, GitHub) : digest retiré pour dédoublonner.
  grep -hoE "(image:|name:|image '|[A-Z]+: |[A-Z]+ = ')[[:space:]]*['\"]?[a-z0-9][a-z0-9._/-]*:[A-Za-z0-9][A-Za-z0-9._-]*(@sha256:[0-9a-f]{64})?" \
      .gitlab-ci.yml bitbucket-pipelines.yml Jenkinsfile .github/workflows/ci.yml \
    | sed -E "s/^(image:|name:|image '|[A-Z]+: |[A-Z]+ = ')[[:space:]]*['\"]?//; s/@sha256:.*//" | sort -u \
    | while read -r img; do ligne outil "$img"; done
} > "$LISTE"

if [ "${1:-}" = "--lisible" ]; then
  jq -r '"\(.famille)\t\(.image)\t\(.contexte)"' "$LISTE"
else
  jq -cs . "$LISTE"
fi
