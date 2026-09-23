# Formation — DevSecOps : intégrer la sécurité dans la chaîne CI/CD

Durée : 3 jours (21 h) · Présentiel · 6 à 10 participants
Public : développeurs, intégrateurs, équipes plateforme et CI/CD, référents sécurité applicative
Prérequis : pratique de Git et d'un langage (Java ou Python), notions de conteneurs
Environnement : plateforme `devsecops-lab` déployée pour la session (un GitLab, un projet et un namespace par participant)

## Objectifs évaluables

À l'issue de la formation, le participant est capable de :

1. Expliquer les principes CALMS et situer les contrôles de sécurité dans le cycle de livraison (shift-left).
2. Construire un pipeline GitLab CI intégrant tests, SAST, détection de secrets, SCA/SBOM et scan d'image, avec des seuils bloquants justifiés.
3. Transposer ce pipeline sur Jenkins et Bitbucket Pipelines.
4. Provisionner une infrastructure avec Terraform (modules, state distant) et en analyser la configuration (Trivy config, tflint).
5. Déployer en GitOps avec Argo CD sur Kubernetes et OpenShift, en respectant les politiques de sécurité des pods.
6. Interpréter un rapport DAST et corriger l'application en conséquence.

## Évaluation des besoins (en amont)

Questionnaire de positionnement par participant (outils utilisés, niveau Git/CI/Kubernetes, contraintes
de l'entreprise : outils imposés, processus de release, exigences de conformité). Les labs sont ajustés :
moteur CI principal, cible Kubernetes ou OpenShift, profondeur Terraform.

## Jour 1 — Culture DevSecOps et pipeline de base

| Séquence | Contenu | Modalité |
|---|---|---|
| 1h | CALMS (Culture, Automation, Lean, Measurement, Sharing) ; coût d'un défaut selon la phase de détection ; atelier « où sont nos contrôles aujourd'hui ? » | Atelier collectif |
| 1h30 | Stratégie de tests : pyramide unitaires / web / intégration, couverture comme garde-fou (pas comme objectif) | Démonstration + lab 1 |
| 2h | GitLab CI : stages, jobs, artefacts, rapports JUnit et couverture ; branche protégée, merge request obligatoire, fusion humaine | Lab 2 : push direct refusé, premier pipeline vert en MR |
| 2h | Secrets : détection, historique Git, rotation ; SAST Semgrep, lecture et tri des résultats (vrai / faux positif) | Lab 3 : secret injecté puis traité |
| 0h30 | Quiz et bilan de la journée | Évaluation formative |

## Jour 2 — Chaîne d'approvisionnement et infrastructure

| Séquence | Contenu | Modalité |
|---|---|---|
| 1h30 | SCA et SBOM (CycloneDX) : vulnérabilités transitives, seuils, exceptions tracées | Lab 4 |
| 1h30 | Images : multi-stage, non-root, construction sans privilège (Buildah), scan d'image | Lab 5 |
| 2h30 | Terraform : providers, modules, state distant et verrouillage, séparation des étapes ; scan IaC | Lab 6 : lecture et extension du module de la plateforme |
| 1h | Jenkins et Bitbucket : transposition du pipeline, points de vigilance (socket Docker, épinglage) | Lab 7 : comparatif guidé |
| 0h30 | Quiz et bilan | Évaluation formative |

## Jour 3 — Déploiement sécurisé et mise en situation

| Séquence | Contenu | Modalité |
|---|---|---|
| 1h30 | GitOps avec Argo CD : état désiré, synchronisation, dérive, rollback ; la CI sans accès au cluster | Lab 8 |
| 1h30 | Kubernetes et OpenShift : Pod Security Admission, SCC, NetworkPolicy, Route | Lab 9 : même application sur les deux cibles |
| 1h | DAST avec ZAP : lecture du rapport, correction (en-têtes de sécurité) | Lab 10 |
| 0h30 | Orchestration de release en entreprise : positionnement de XL Release / XL Deploy face au GitOps | Exposé + discussion |
| 2h | Mise en situation : une vulnérabilité, un secret et une dérive de configuration sont introduits ; chaque participant les détecte et les corrige jusqu'au déploiement | Évaluation sommative |

## Supports

Cas concrets de chaque gate (sorties réelles des outils, scénarios à rejouer) : `docs/gates-securite.md`.
Cas réels du dépôt : `docs/journal-securite.md`.

## Suivi et évaluation

- Positionnement initial, quiz de fin de journée, mise en situation finale notée sur grille.
- Suivi individuel de progression (état des labs par participant dans GitLab) ; accompagnement ajusté en séance.
- Questionnaire de satisfaction à chaud, bilan à froid à 3 mois sur la mise en pratique.
