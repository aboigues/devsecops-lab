#!/usr/bin/env bash
# Crée le dépôt d'entraînement du TP02 : l'historique de Léa, dont un commit contient une clé AWS.
# La clé est GÉNÉRÉE à chaque exécution (fausse, jamais valide chez AWS) : aucun secret n'est
# versionné dans ce dépôt de formation, et la gate secrets du dépôt reste verte.
# Usage : ./creer-depot.sh <dossier>
set -euo pipefail

DEST="${1:?usage : $0 <dossier>}"
[ ! -e "$DEST" ] || { echo "$DEST existe déjà : choisissez un autre dossier ou supprimez-le."; exit 1; }

aleatoire() { LC_ALL=C tr -dc "$1" </dev/urandom | head -c "$2" || true; }
CLE_ID="AKIA$(aleatoire 'A-Z2-7' 16)"
CLE_SECRETE="$(aleatoire 'A-Za-z0-9' 40)"

git init -q -b main "$DEST"
cd "$DEST"
git config user.name "Léa (développeuse)"
git config user.email "lea@neobanque.example"
git config commit.gpgsign false

cat > application.properties <<CONF
spring.application.name=bank-api
server.port=8080
bank.exports.bucket=exports-neobanque
CONF
git add application.properties
git commit -q -m "feat: configuration initiale"

cat >> application.properties <<CONF
# Clé de test pour lire un fichier d'exemple dans le bucket (à retirer avant la MR)
aws.access-key-id=${CLE_ID}
aws.secret-access-key=${CLE_SECRETE}
CONF
git add application.properties
git commit -q -m "feat: lecture des exports depuis le bucket"

sed -i '/^# Clé de test/d; /^aws\./d' application.properties
echo 'aws.credentials=${AWS_PROFILE}' >> application.properties
git add application.properties
git commit -q -m "fix: retrait de la clé de test"

echo "Dépôt créé dans $DEST ($(git rev-list --count HEAD) commits)."
