# Formation DevSecOps — Travaux pratiques

Les travaux pratiques de la formation DevSecOps (programme : [`docs/formation/programme-devsecops.md`](../docs/formation/programme-devsecops.md)).
Ici, on **apprend en faisant** : chaque TP part d'un squelette à compléter, et la cible est vérifiée
par un script, pas par une impression.

Chaque TP met en pratique une des gates de sécurité du dépôt ([`docs/gates-securite.md`](../docs/gates-securite.md))
et reprend un épisode de l'étude de cas [Néobanque Exemple](../docs/scenario-entreprise.md). Tous se
font **en local**, sans compte cloud : la plateforme Scaleway (GitLab, Argo CD) sert aux labs de
bout en bout et à la mise en situation finale.

---

## Comment fonctionnent les TP

Chaque TP est un dossier autonome :

```
tpNN-nom/
├── README.md      <- le guide pas à pas (commencez TOUJOURS par là)
├── starter/       <- les fichiers À COMPLÉTER (cherchez les « TODO »)
├── solution/      <- la solution de référence (à consulter en dernier recours)
└── verify.sh      <- le script de validation (le même que la CI)
```

Certains TP ont un dossier de plus : `mutants/` (TP01), `controle/` et `controles/` (TP03, TP06),
`projet/` (TP04). Ils appartiennent au script de validation : on les lit, on ne les modifie pas.

### La règle d'or

> **Une gate qui n'a jamais bloqué n'est pas une gate.**

Chaque `verify.sh` vérifie deux choses : que votre travail atteint la cible, **et** que le contrôle
que vous avez mis en place bloque vraiment ce qu'il doit bloquer (mutants du TP01, Log4Shell réinjecté
au TP04, clé AWS recommitée au TP02...). La CI du dépôt ([`.github/workflows/tp.yml`](../.github/workflows/tp.yml))
rejoue chaque TP sur sa `solution/`, qui doit passer, et sur son `starter/`, qui doit échouer.

### Votre méthode de travail

1. **Lisez le `README.md`** du TP en entier avant de taper la moindre commande.
2. **Travaillez dans `starter/`** : complétez les fichiers marqués `TODO`.
3. **Validez vous-même** : `./verify.sh` depuis le dossier du TP.
4. **Bloqué ?** Relisez la section « Indices », puis seulement en dernier recours, regardez `solution/`.
5. **En avance ?** Faites la section « Pour aller plus loin » : elle est là pour ça.

---

## Parcours

| TP | Sujet | Épisode Néobanque Exemple | Programme |
|----|-------|---------------------------|-----------|
| [TP01](tp01-tests-couverture/) | Tests et couverture, tests de mutation | Un contrôle de solde supprimé en silence | Jour 1, lab 1 |
| [TP02](tp02-secrets/) | Secrets : purger l'historique, hook pre-commit | Lundi : la clé AWS de Léa | Jour 1, lab 3 |
| [TP03](tp03-sast/) | SAST : injection SQL, tri des faux positifs | Lundi : la requête concaténée | Jour 1, lab 3 |
| [TP04](tp04-sca-sbom/) | SCA et SBOM : une gate qui bloque, un inventaire qui répond | Mercredi : l'alerte CVE | Jour 2, lab 4 |
| [TP05](tp05-image-durcie/) | Image durcie : multi-stage, non-root, épinglée | Le micro-service refusé en revue | Jour 2, lab 5 |
| [TP06](tp06-iac-terraform/) | Terraform : validations et `terraform test` | Le scanner qui ne voit rien | Jour 2, lab 6 |
| [TP07](tp07-securite-ci/) | Sécuriser la CI : injection de workflow | Le pipeline est une cible | Jour 2, démonstration |
| [TP08](tp08-kubernetes-psa/) | Kubernetes : Pod Security `restricted`, NetworkPolicy | Le Deployment privilégié | Jour 3, lab 9 |
| [TP09](tp09-dast-zap/) | DAST : ZAP contre l'application démarrée | Jeudi : la mise en production | Jour 3, lab 10 |

La progression suit le cycle de livraison, **du poste du développeur à la production** : le code et ses
tests (TP01), ce qu'on commite (TP02), ce qu'on écrit (TP03), ce qu'on embarque (TP04), ce qu'on
emballe (TP05), l'infrastructure (TP06), la chaîne elle-même (TP07), ce qu'on déploie (TP08), ce qui
tourne (TP09).

Sur la plateforme déployée (voir le [README](../README.md) du dépôt) : lab 2 (merge request obligatoire,
push direct sur `main` refusé), lab 7 (Jenkins et Bitbucket, [`docs/comparatif-ci.md`](../docs/comparatif-ci.md)),
lab 8 (GitOps avec Argo CD, promotion par merge request) et la mise en situation du jour 3.

---

## Prérequis

- **Linux ou WSL2**, un shell `bash`, `git`, `curl`, `jq`, **`yq` v4** (https://github.com/mikefarah/yq)
- **Docker** (TP05, TP09)
- **JDK 25** et **Maven 3.9** (TP01, TP03, TP04)
- **Terraform 1.14 ou plus** (TP06)
- Les outils de sécurité, aux versions de la CI, installés par un script qui vérifie leurs empreintes
  SHA-256 (Trivy, gitleaks, Semgrep, zizmor) :

```bash
tp/scripts/installer-outils.sh          # installe dans ~/.local/bin
```

Piège connu : le `yq` installé par snap (Ubuntu) ne peut pas lire `/tmp` ; préférez le binaire publié
sur GitHub.

---

## Tester comme la CI

Depuis n'importe quel dossier de TP :

```bash
cd tp/tp01-tests-couverture
./verify.sh             # votre travail (starter/)
./verify.sh solution    # la solution de référence
```

---

## Conventions

- Les commandes destructrices (réécriture d'historique, `push --force`) sont **toujours signalées**.
- Chaque `verify.sh` travaille sur une copie ou nettoie ses ressources (conteneurs, images, réseaux).
- Ports utilisés : `8085` (TP05), `8089` (TP09).
- **Aucun secret n'est versionné**, même factice : la clé AWS du TP02 est générée à chaque exécution,
  et la gate secrets du dépôt scanne tout l'historique.
- Les `starter/` sont **volontairement vulnérables** ; ils sont exclus de l'analyse CodeQL du dépôt,
  les `solution/` restent analysées (exception tracée dans [`docs/journal-securite.md`](../docs/journal-securite.md)).
- Toute sortie d'outil citée dans un README a été réellement obtenue, avec la version de l'outil.

Et surtout : **tapez les commandes vous-même.**

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
