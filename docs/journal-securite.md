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

## 2026-09-25 — Scanner IaC aveugle sur les ressources Scaleway (trivy config)

- **Détection** : écriture du TP06 (`tp/tp06-iac-terraform`), module volontairement mal configuré.
- **Constat** : `trivy config` (0.74.0, toutes sévérités) rend **0 constat** sur un module Scaleway qui
  ouvre SSH à `0.0.0.0/0` par défaut, accepte par défaut tout trafic entrant et publie un bucket en
  `public-read`. Aucune règle de Trivy ne couvre ces ressources Scaleway. Le « 0 constat » du job `iac`
  sur `terraform/` ne prouve donc rien pour la plateforme elle-même.
- **Analyse** : la plateforme n'est pas exposée aujourd'hui (validation `admin_cidrs` qui refuse
  `0.0.0.0/0`, `inbound_default_policy = "drop"`, bucket de state privé), mais ces protections reposent
  sur la relecture, pas sur un contrôle automatique.
- **Traitement** : le TP06 enseigne la parade (blocs `validation` et `terraform test` avec fournisseur
  simulé, sans compte ni coût). Suite prévue : des tests `terraform test` pour les modules de
  `terraform/modules/`, exécutés par le job `iac`.
- **Enseignement** : un scanner vert ne vaut que pour ce qu'il sait lire. Vérifier la couverture d'un
  outil sur son propre fournisseur avant de se fier à son silence.

## 2026-09-25 — Énoncés de TP volontairement vulnérables exclus de CodeQL (exception)

- **Contexte** : les `starter/` des travaux pratiques (`tp/`) contiennent des défauts **voulus** : une
  injection SQL (TP03), un workflow GitHub injectable (TP07). CodeQL (`build-mode: none`) analyse tout le
  code Java et Actions du dépôt : ces énoncés lèveraient des alertes bloquantes.
- **Décision** : `paths-ignore: tp/*/starter/**` dans `.github/codeql/codeql-config.yml`. Exception ciblée
  (les seuls `starter/`), les `solution/` restent analysées.
- **Mesures compensatoires** : les énoncés ne sont ni construits ni livrés ; le workflow `tp` vérifie que
  chaque `starter/` échoue à sa validation (le défaut est intentionnel et détecté) et que chaque
  `solution/` la passe. Aucun secret n'est versionné, même factice : la clé AWS du TP02 est générée à
  l'exécution, la gate secrets reste donc sans exception. Le workflow du TP07 est hors de
  `.github/workflows/` : il n'est jamais exécuté par GitHub.
- **À revoir** : si un `starter/` devait un jour être construit ou déployé.

## 2026-09-25 — Images Argo CD du lab vulnérables (scan hebdomadaire des images)

- **Détection** : mise au point du workflow `scan-images` (Trivy 0.74.0), qui scanne chaque lundi les
  images construites, déployées et utilisées par le dépôt, et non plus seulement à chaque PR.
- **Constat** : le chart Argo CD 10.9.2 (dernière version publiée, 2026-09-17) déployé par `terraform/labs`
  embarque des vulnérabilités HIGH/CRITICAL de **paquets OS corrigeables** : 8 dans
  `redis:8.6.4-alpine`, 17 dans `ghcr.io/dexidp/dex:v2.45.1` (133 corrigeables au total, binaires Go
  compris). `quay.io/argoproj/argocd:v3.5.3` : 0 au niveau OS (115 dans ses binaires, non bloquantes).
  Les images construites par le dépôt (`bank-api`, image du TP05) sont à 0.
- **Analyse** : monter le chart ne corrige rien, il est déjà à jour. `redis:8.6.7-alpine` est mesurée à
  0 vulnérabilité OS corrigeable. dex v2.45.1 est la dernière version publiée (mars 2026) ; or le lab ne
  configure aucun SSO : dex y est une surface d'attaque sans usage.
- **Remédiation** (PR séparée, même jour) : les valeurs du chart passent dans
  `terraform/labs/argocd-values.yaml`, lu par Terraform **et** par le scan (ce qui est scanné est ce qui
  est déployé). redis surchargée en `8.6.7-alpine` épinglée par digest ; dex désactivé
  (`dex.enabled: false`). Rendu du chart vérifié (plus de Deployment dex) ; barrière du scan verte sur
  les deux images déployées restantes (redis, argocd).
- **Reste à faire** : valider en déploiement réel (connexion admin à Argo CD, synchronisation des
  applications apprenants) lors du prochain `apply` du lab.
- **Images d'outils des pipelines** (informatif, non bloquant) : vulnérabilités corrigeables mesurées
  dans `zaproxy/zap-stable:2.17.0` (157), `zricethezav/gitleaks:v8.30.1` (56),
  `atlassian/default-image:4` (423) ; 0 pour `maven:3.9.16-eclipse-temurin-25` et `quay.io/buildah/stable:v1.43.4`.
  Ces images ne sont pas livrées, mais elles s'exécutent dans la CI avec le code : à surveiller aux
  montées de version.
- **Enseignement** : une image verte le jour de la PR ne le reste pas. Le scan périodique constate la
  dérive ; la correction dépend de qui maîtrise l'image, d'où une politique de blocage par famille.

## 2026-09-25 — Alertes orphelines dans l'onglet Security (défaut de conception du scan d'images)

- **Détection** : premier scan hebdomadaire sur `main` après la correction d'Argo CD : scan vert, mais
  141 alertes Trivy toujours ouvertes pour dex (retiré) et redis 8.6.4 (remplacée par 8.6.7).
- **Cause** : la catégorie SARIF contenait le tag de l'image (`trivy-image-...-redis-8.6.4-alpine`). Une
  alerte ne se ferme que si la **même catégorie** est renvoyée sans elle ; une image retirée ou montée de
  version n'était plus jamais renvoyée sous son ancienne catégorie. Chaque montée de version aurait
  laissé des alertes ouvertes à vie, rendant l'onglet Security inutilisable.
- **Remédiation** : catégorie stable par image, sans tag ni digest (`trivy-deployee-...-redis`) ;
  suppression des analyses `trivy-image-*` obsolètes via l'API. Les images d'outils des pipelines
  (1 299 alertes sur 1 555, sans action possible) ne sont plus envoyées dans l'onglet Security :
  synthèse du run et artefact seulement.
- **Enseignement** : un tableau d'alertes n'est utile que si une alerte corrigée se ferme toute seule.
  Tester le cycle complet (apparition, correction, fermeture), pas seulement l'apparition.

## 2026-09-26 — Premier déploiement réel : neuf défauts qu'aucune CI n'avait vus

- **Contexte** : premier `apply` complet sur Scaleway (projet et application IAM dédiés), puis parcours d'un
  apprenant de bout en bout : merge request, pipeline GitLab, fusion humaine, merge request GitOps du bot,
  fusion humaine, synchronisation Argo CD. Toutes les CI GitHub étaient vertes ; ces défauts n'existent
  qu'au contact de la vraie plateforme.
- **Constats et traitements** :
  1. *Quota* : `DEV1-XL` a un quota de 0 sur l'organisation, l'`apply` s'arrête au serveur GitLab. Type par
     défaut passé à `BASIC2-A4C-16G` (4 vCPU / 16 Go, prix voisin).
  2. *Jetons PAT jamais créés* : `gitlab-rails runner` s'exécute sous l'utilisateur `git`, qui ne peut pas
     lire `/root` (700). Le runner attendait indéfiniment son jeton. Script copié dans `/var/opt/gitlab`
     (propriétaire `git`, 600), exécuté, puis effacé (`shred`) avec l'original.
  3. *Import de projet refusé (403)* sur un projet sur deux : GitLab garde ses réglages d'instance en cache
     dans chaque processus web ; l'activation de l'import n'était pas encore visible partout. Pause de 90 s
     (`time_sleep`) après l'activation.
  4. *Configuration CI rejetée* : le job de construction s'appelait `image`, mot-clé réservé de GitLab CI
     (image par défaut). Aucun job n'était créé. Renommé `build-image`.
  5. *Job GitOps invalide* : `- git commit -am "chore(gitops): ..."` est lu par YAML comme une clé (« : »).
     Ligne mise entre apostrophes. Détecté grâce au linter CI de GitLab une fois le défaut 4 levé.
  6. *SCA bloquée par Maven Central* : `trivy fs` sur le `pom.xml` interroge Maven Central, qui répond 429 et
     bloque l'IP du runner 30 minutes. Comme sur GitHub depuis le 2026-09-23, le JAR construit est analysé
     hors ligne (`trivy rootfs --offline-scan`) ; aligné aussi dans Jenkins et Bitbucket.
  7. *Aucun SAST ni détection de secrets sur les merge requests* : depuis GitLab 17, les modèles ne tournent
     dans un pipeline de MR que si `AST_ENABLE_MR_PIPELINES` vaut `true`. Variable ajoutée. Constat lié :
     ces jobs sont en `allow_failure` en édition CE, donc informatifs (limite documentée dans le README).
  8. *Buildah bloqué* : `unshare(CLONE_NEWUSER)` refusé par le profil seccomp par défaut de Docker, puis
     `remount /` refusé par AppArmor. Vérifié par essais sur la VM runner. Décision : un **second runner,
     dédié** (tag `buildah`, aucun job sans tag) dont les conteneurs n'ont ni seccomp ni AppArmor, toujours
     sans `--privileged` ni capacité ajoutée ; seul le job `build-image` l'utilise.
  9. *Noms d'image courts refusés par Buildah* (`short-name resolution enforced`) : images de base qualifiées
     `docker.io/library/...` dans `app/Dockerfile` (digests inchangés).
- **Vérifié en réel après correction** : pipeline de MR vert (8 jobs, dont DAST ZAP : 66 règles OK, 10049 en
  INFO tracé), pipeline de `main` et MR GitOps ouverte par le bot, deux fusions humaines, application
  `Synced` et `Healthy`, pods non-root admis en Pod Security `restricted`, pas de boucle GitOps. La règle
  « discussions résolues » a bloqué une fusion tant qu'un commentaire en fil restait ouvert.
- **Corrigé en direct puis reporté dans le code, à revérifier au prochain déploiement** : défauts 2 et 8
  (cloud-init rendu et vérifié, pas encore rejoué sur une VM neuve), défaut 3.
- **Pistes** : ne pas rejouer la construction d'image sur une MR GitOps (seul `gitops/` change) ; une gate
  bloquante lisant le rapport SAST en édition CE.
- **Enseignement** : une chaîne entièrement verte en CI n'a encore rien prouvé sur la plateforme. Chaque
  gate doit être exercée au moins une fois dans son environnement réel.
