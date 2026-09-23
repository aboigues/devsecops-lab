# devsecops-lab

Plateforme de formation DevSecOps déployée à la demande sur Scaleway par Terraform
(voir `README.md` pour l'architecture et le déroulé).

## Règles critiques

- **Jamais de commit ni de push sur `main`** : toujours une branche + une PR. **Claude ne fusionne jamais une PR**
  (ni `gh pr merge`, ni approbation) : seul Alexandre fusionne. Interdictions matérialisées dans
  `.claude/settings.json` et par le ruleset GitHub de `main`.
- **Toujours répondre en français**, orthographe complète (accents, diacritiques). Tutoyer Alexandre.
- **Zéro emoji** — partout, sans exception (code, docs, commits, réponses).
- **Aucun `terraform apply` ni `destroy` sans accord explicite d'Alexandre dans la session en cours.**
  Une validation donnée un autre jour ne vaut pas pour aujourd'hui.
- **Toujours détruire après un test** (`labs` puis `platform`) et vérifier qu'il ne reste aucune ressource
  facturée (`scw instance server list`, `scw k8s cluster list`, IP flexibles, volumes).
- **`--profile telemach`** sur toutes les commandes `scw` ; pour Terraform : `export SCW_PROFILE=telemach`.
- **Versions** : ne jamais se fier à la mémoire du modèle ; vérifier la dernière version stable
  (registry Terraform, Docker Hub, Maven Central, releases GitHub) avant toute mise à jour.
- **Dépôt public** : ne jamais commiter de secret, d'IP personnelle, de `*.tfvars`, de `backend.hcl`
  ni de state. Vérifier `git status` avant chaque commit.

## Conventions

- Étapes Terraform séparées : `bootstrap` (state local, une fois) -> `platform` -> `labs`.
- Toute exception de sécurité (`.trivyignore`, seuil abaissé) est justifiée, datée et consignée dans
  `docs/journal-securite.md`. Tout constat réel traité y est aussi consigné.
- Les contrôles du pipeline sont bloquants ; on corrige la cause plutôt que de baisser un seuil.
- Commits en français, format conventionnel (`feat:`, `fix:`, `docs:`...).

## Vérifications locales avant push (sur la branche de la PR)

```bash
terraform fmt -check -recursive terraform/
for d in bootstrap platform labs; do terraform -chdir=terraform/$d init -backend=false -input=false >/dev/null && terraform -chdir=terraform/$d validate; done
trivy config --severity MEDIUM,HIGH,CRITICAL terraform/
(cd app && mvn -B verify)   # nécessite JDK 25 (le JDK local du poste est le 21)
```

Pièges connus du poste : Docker non disponible dans WSL ; Maven Central renvoie 429 aux scans
`trivy fs` sur `pom.xml` (scanner le JAR construit hors ligne, depuis un chemin Linux).

## Contexte local

Si `CLAUDE.local.md` existe (non versionné), le lire : il contient le suivi en cours.
