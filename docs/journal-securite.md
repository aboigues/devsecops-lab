# Journal de sécurité

Constats réels relevés par la chaîne sur ce dépôt, et leur traitement. Sert aussi de cas d'étude en formation.

## 2026-09-23 — Tomcat embarqué vulnérable (SCA)

- **Détection** : `trivy` sur l'artefact `bank-api-0.0.1-SNAPSHOT.jar`, dès la première construction.
- **Constat** : `tomcat-embed-core` 11.0.24, version gérée par Spring Boot 4.1.1 (dernière version
  stable du jour), porte 3 CVE **CRITICAL** corrigées en 11.0.25 : CVE-2026-65182 (contournement de
  contrainte de sécurité), CVE-2026-65905 (rejeu DIGEST), CVE-2026-68525 (contournement FORM).
- **Exposition réelle** : faible pour cette API (ni DIGEST ni FORM, pas de contrainte de sécurité
  déclarative), mais le seuil du pipeline est volontairement indépendant de cette analyse :
  un correctif existe, donc on l'applique.
- **Remédiation** : surcharge de la propriété `tomcat.version` à 11.0.26 dans `app/pom.xml`,
  commentée avec les CVE et la condition de retrait.
- **Vérification** : 13 tests verts, nouveau scan à 0 vulnérabilité HIGH/CRITICAL.
- **Enseignement** : « dernière version du framework » ne veut pas dire « sans vulnérabilité connue ».
  Le scan de dépendances doit tourner à chaque build, pas seulement lors des montées de version.

## 2026-09-23 — Registry hors liste de confiance (IaC, KSV-0125)

- **Détection** : `trivy config` sur les overlays Kustomize rendus, dans la CI GitHub (échec bloquant du job `iac`).
- **Constat** : l'image provient d'un registry absent de la liste de confiance par défaut de Trivy.
- **Analyse** : le registry légitime est celui du GitLab du lab, dont l'hôte change à chaque déploiement.
- **Décision** : exception documentée dans `.trivyignore` (justification, date, mesure compensatoire),
  plutôt qu'un abaissement global du seuil. Cible en production : politique d'admission Kyverno ou
  OPA Gatekeeper restreignant les registries autorisés.
- **Enseignement** : une exception de sécurité est une décision tracée, pas une désactivation silencieuse.

## 2026-09-23 — Promotion en lab sans relecture humaine (conception du pipeline)

- **Détection** : revue de conception, lors de la mise en place de la protection de `main`.
- **Constat** : le job GitOps poussait le nouveau tag d'image directement sur `main` avec un jeton
  `maintainer`. Tout commit applicatif était donc déployé en lab sans qu'un humain voie la promotion,
  et le jeton du bot pouvait modifier n'importe quel fichier de `main`.
- **Remédiation** : `main` protégée en « no one » pour le push (`gitlab_branch_protection`), le job
  devient `gitops:propose` et ouvre une merge request ; jeton du bot abaissé à `developer` (ne peut
  pas fusionner). Mêmes principes appliqués au `Jenkinsfile` et à `bitbucket-pipelines.yml`.
- **Enseignement** : le GitOps ne sécurise le déploiement que si l'écriture dans le dépôt de
  configuration est elle-même contrôlée. Un bot qui pousse sur `main` est un déploiement continu
  sans porte.

## 2026-09-23 — Dependabot sans délai de carence (sécurité de la CI, zizmor)

- **Détection** : `zizmor` 1.30.1, avant le premier push de la configuration Dependabot
  (4 alertes MEDIUM `dependabot-cooldown`).
- **Constat** : sans délai, Dependabot propose une nouvelle version dès sa publication. Or les
  compromissions de paquets sont en général détectées et retirées dans les jours qui suivent.
- **Remédiation** : `cooldown: { default-days: 7 }` sur chaque écosystème. Les mises à jour de
  sécurité ne sont pas retardées.
- **Enseignement** : la configuration de la CI est du code, elle passe elle aussi par une gate.

## 2026-09-23 — Protection de `main` et agent IA

- **Décision** : ruleset GitHub sans exception (PR obligatoire, toutes les gates exigées, historique
  linéaire, ni force-push ni suppression). 0 approbation exigée car le dépôt n'a qu'un mainteneur
  et GitHub interdit d'approuver sa propre PR.
- **Risque résiduel** : Claude Code utilise le jeton d'Alexandre ; GitHub ne peut pas distinguer une
  fusion humaine d'une fusion par l'agent.
- **Mesure compensatoire** : `.claude/settings.json` (versionné, relu via CODEOWNERS) interdit à
  l'agent le push vers `main`, le force-push, `gh pr merge`, l'approbation de PR et la modification
  des rulesets ; fusion automatique désactivée ; `GITHUB_TOKEN` en lecture seule, sans droit
  d'approbation. Cible en équipe : 1 approbation minimum par un CODEOWNER.

## 2026-09-23 — Première exécution réelle du DAST (ZAP, faux positif tracé)

- **Détection** : job `container` de la CI GitHub, PR #1, ZAP baseline 2.17.0 contre l'API démarrée.
- **Constat** : 66 règles passent, 1 avertissement `Non-Storable Content [10049]` sur 4 URL : les
  réponses ne sont pas stockables en cache.
- **Analyse** : comportement voulu (`Cache-Control: no-store` posé par `SecurityHeadersFilter`),
  recommandé pour des données financières (OWASP ASVS V8.2.1). Faux positif dans ce contexte.
- **Décision** : règle 10049 rétrogradée en INFO dans `.zap/baseline.conf` (justifiée, datée), et non
  `-I` qui masquerait tous les avertissements. Appliqué aux quatre pipelines.
- **Enseignement** : un outil DAST signale des faits, pas des vulnérabilités ; le tri se fait au regard
  du contexte métier, et la décision est tracée.

## 2026-09-23 — Mise à jour automatique régressive bloquée (Dependabot, PR #2)

- **Détection** : job `container` de la CI, sur la PR #2 ouverte par Dependabot quelques minutes après
  l'activation de la configuration.
- **Constat** : « montée de version » de l'image de build `maven:3.9.16-eclipse-temurin-25` vers
  `maven:3-eclipse-temurin-24`. En réalité une régression : JDK 25 (LTS) remplacé par JDK 24 (hors LTS,
  fin de support), et tag flottant `3` au lieu d'une version exacte. La compilation échoue :
  `release version 25 not supported`. Dependabot interprète mal les tags composés
  `<maven>-eclipse-temurin-<jdk>`.
- **Remédiation** : images de base épinglées par tag **et** digest ; Dependabot limité aux mises à jour
  de digest pour `maven` et `eclipse-temurin` (même version reconstruite avec les correctifs OS). Les
  changements de version se font à la main après vérification de la dernière version stable
  (3.9.16 / JDK 25 le 2026-09-23). PR #2 non fusionnée.
- **Enseignement** : une mise à jour automatique n'est pas une mise à jour sûre. Sans gate bloquante
  et sans fusion humaine, cette PR aurait été fusionnée automatiquement ; ici la CI l'a arrêtée et un
  humain a tranché.
