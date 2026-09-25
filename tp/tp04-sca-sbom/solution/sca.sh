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

# 2. SBOM d'abord : il doit exister même quand la gate échoue (c'est justement là qu'on en a besoin).
#    --offline-scan : l'identification des JAR se fait hors ligne, sans interroger Maven Central.
trivy rootfs --quiet --offline-scan --format cyclonedx \
  --output "$PROJET/target/sbom.cdx.json" "$PROJET/target/dependency"

# 3. La gate : HIGH/CRITICAL corrigeables uniquement (une alerte sans correctif ne se traite pas en
#    montant de version : elle relève d'une exception tracée).
trivy rootfs --quiet --offline-scan --scanners vuln \
  --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$PROJET/target/dependency"
