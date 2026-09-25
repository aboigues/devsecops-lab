#!/usr/bin/env bash
# Gate SCA + SBOM d'un projet Maven.
#   - échoue (code non nul) si une dépendance embarquée a une vulnérabilité HIGH ou CRITICAL
#     pour laquelle un correctif existe ;
#   - produit dans tous les cas le SBOM CycloneDX <projet>/target/sbom.cdx.json.
# Usage : ./sca.sh <dossier du projet Maven>
set -euo pipefail
PROJET="$(cd "${1:?usage : $0 <projet>}" && pwd)"

# 1. Ce qui sera réellement livré : les JAR des dépendances d'exécution (pas celles de test).
mvn -B -q -f "$PROJET/pom.xml" package dependency:copy-dependencies -DincludeScope=runtime

# TODO 1 : produire le SBOM CycloneDX de "$PROJET/target/dependency" dans
#          "$PROJET/target/sbom.cdx.json" (trivy rootfs, identification hors ligne).

# TODO 2 : la gate. Scanner "$PROJET/target/dependency" : vulnérabilités seulement,
#          sévérités HIGH et CRITICAL, uniquement celles qui ont un correctif,
#          et un code de sortie NON NUL si on en trouve.
trivy rootfs --offline-scan "$PROJET/target/dependency"
