# TP02 — Secrets : supprimer la clé ne suffit pas

> Durée estimée : 1 h · Programme : jour 1, lab 3 · Gate : [Gate 3](../../docs/gates-securite.md#gate-3--secrets--supprimer-la-clé-ne-suffit-pas)
> Prérequis : git, **gitleaks 8.30** (`tp/scripts/installer-outils.sh`).

## Le contexte

Lundi, Léa a collé une clé AWS de test dans `application.properties` pour lire un fichier d'exemple.
Elle s'en est rendu compte et l'a retirée dans le commit suivant. Le fichier est propre, la merge request
aussi... mais **la clé est toujours dans l'historique** : quiconque clone le dépôt la retrouve avec
`git log -p`. Des robots parcourent GitHub en continu à la recherche de ce motif `AKIA...` ; une clé
publiée est exploitée en quelques minutes.

L'ordre de la remédiation compte :

1. **Révoquer la clé** chez le fournisseur (ici fictif) : c'est la seule action qui la rend inoffensive.
2. **Purger l'historique** : pour que le dépôt cesse de la diffuser (et que la gate redevienne verte).
3. **Empêcher la récidive** : un hook local qui refuse le commit, et la gate de CI qui scanne l'historique.

## Objectif vérifiable

Après votre script, `gitleaks git` ne trouve plus rien, la clé n'existe plus dans **aucun objet git**
(même inaccessible), les 3 commits et le reste de la configuration sont intacts, et votre hook
`pre-commit` refuse un nouveau commit contenant une clé. `./verify.sh` contrôle tout cela.

---

## Étape 1 — Reproduire le problème

Le script `creer-depot.sh` fabrique le dépôt de Léa. La clé est **générée à chaque fois** : elle est
fausse, et aucun secret n'est versionné dans ce dépôt de formation.

```bash
./creer-depot.sh /tmp/depot-lea
cd /tmp/depot-lea
git log --oneline
cat application.properties                 # propre
gitleaks dir . --redact                    # « no leaks found »
gitleaks git . --redact -v                 # 2 fuites, dans le commit du milieu
```

> **Question** : gitleaks trouve **deux** secrets, avec deux règles différentes (`aws-access-token` et
> `generic-api-key`). Pourquoi la seconde est-elle plus sujette aux faux positifs ? Sur quoi s'appuie-t-elle ?

## Étape 2 — Purger l'historique (TODO 1 à 3)

Complétez `starter/nettoyer-historique.sh`. Trois temps :

1. **Réécrire** chaque commit de toutes les branches pour retirer les lignes `aws.*` (et leur commentaire).
   `git filter-branch --tree-filter "<commande>" -- --all` exécute la commande dans chaque commit.
2. **Supprimer `refs/original/`** : filter-branch y garde une sauvegarde de l'ancien historique.
3. **Vider le reflog et lancer le ramasse-miettes** : sinon les anciens objets restent sur le disque.

Testez sur une copie fraîche à chaque essai :

```bash
rm -rf /tmp/depot-lea && ./creer-depot.sh /tmp/depot-lea
./starter/nettoyer-historique.sh /tmp/depot-lea
gitleaks git /tmp/depot-lea --redact
```

> **Question** : vous avez purgé votre dépôt. Qu'en est-il des clones des collègues, des forks, des caches
> de la CI, de l'artefact de build d'hier ? Pourquoi la révocation reste-t-elle **indispensable** ?

> **Attention, commande destructrice** : sur un vrai dépôt, la réécriture change tous les identifiants de
> commit et impose un `git push --force` coordonné avec toute l'équipe. On la réserve aux vrais secrets.

## Étape 3 — Empêcher la récidive (TODO 4)

Complétez `starter/pre-commit` : lancer gitleaks sur les **seules modifications indexées**. Installez-le
dans le dépôt de Léa et essayez de recommettre une clé :

```bash
cp starter/pre-commit /tmp/depot-lea/.git/hooks/pre-commit
chmod +x /tmp/depot-lea/.git/hooks/pre-commit
```

> **Question** : `git commit --no-verify` contourne le hook. Pourquoi le hook reste-t-il utile, et pourquoi
> ne remplace-t-il pas le scan de l'historique en CI (`fetch-depth: 0` dans `.github/workflows/ci.yml`) ?

## Étape 4 — Validez

```bash
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

---

## Indices

<details>
<summary>La réécriture</summary>

```bash
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --tree-filter \
  "sed -i '/^aws\.access-key-id=/d; /^aws\.secret-access-key=/d' application.properties" -- --all
```

Le premier commit ne contient pas encore les lignes : `sed -i` ne fait rien, sans erreur.
</details>

<details>
<summary>Faire disparaître les anciens objets</summary>

```bash
git for-each-ref --format='%(refname)' refs/original/ | xargs -r -n 1 git update-ref -d
git reflog expire --expire=now --all
git gc --prune=now
```

Vérification : `git cat-file --batch-all-objects --batch | grep -a AKIA` ne doit rien renvoyer.
</details>

<details>
<summary>Le hook</summary>

```bash
exec gitleaks git --pre-commit --staged --redact --exit-code 1 .
```
</details>

---

## Où chercher (documentation officielle)

- **gitleaks** : https://github.com/gitleaks/gitleaks
- **Retirer des données sensibles d'un dépôt (GitHub)** : https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
- **git filter-repo** (outil recommandé en entreprise) : https://github.com/newren/git-filter-repo
- **Push protection GitHub** : https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection
- **Détection de secrets GitLab** : https://docs.gitlab.com/user/application_security/secret_detection/

---

## Pour aller plus loin

1. **git filter-repo.** Refaites la purge avec `git filter-repo --replace-text`. Comparez la vitesse et la
   simplicité. Pourquoi filter-repo refuse-t-il par défaut de travailler sur un dépôt qui n'est pas un clone frais ?
2. **Faux positif.** Ajoutez une ligne `exemple.cle=AKIAIOSFODNN7EXAMPLE` (la clé d'exemple de la
   documentation AWS). gitleaks la signale-t-il ? Comment déclarer une exception **ciblée** (`.gitleaksignore`,
   empreinte du constat) plutôt que de désactiver la règle ?
3. **La bonne configuration.** Remplacez la clé par une variable d'environnement, puis par un rôle IAM
   (aucune clé du tout). Quel est l'équivalent sur Scaleway (voir `terraform/platform`, Secret Manager) ?
4. **pre-commit framework.** Installez le hook via le framework `pre-commit` (fichier
   `.pre-commit-config.yaml`) pour le partager avec toute l'équipe.

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
