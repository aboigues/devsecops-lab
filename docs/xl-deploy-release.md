# XL Deploy et XL Release (Digital.ai) dans une chaîne DevSecOps

Niveau de ce document : **notions** — lecture de la documentation éditeur et correspondance avec les
outils pratiqués dans ce lab. Il sert à situer ces outils, très présents dans le secteur bancaire,
face aux approches GitOps.

## Rôles

- **XL Deploy (Digital.ai Deploy)** : déploiement orienté modèle. On décrit un *package* versionné
  (Deployment Package : artefacts + configuration), des *environnements* composés d'*infrastructures*
  cibles (serveurs, clusters, middleware), et des *dictionnaires* de valeurs par environnement.
  L'outil calcule le plan de déploiement (étapes, ordre, rollback).
- **XL Release (Digital.ai Release)** : orchestration de la release de bout en bout. Des *templates* de
  release enchaînent phases et tâches (automatiques ou manuelles : validation CAB, tests, déploiement
  via XL Deploy, notifications), avec traçabilité et tableaux de bord de conformité.

## Correspondance avec ce lab

| XL Deploy / XL Release | Équivalent dans le lab |
|---|---|
| Deployment Package | Image OCI + manifestes Kustomize à un tag donné |
| Environnement / Infrastructure | Namespace Kapsule / cluster, déclarés par Terraform |
| Dictionnaire | Overlay Kustomize (`gitops/overlays/*`) |
| Plan de déploiement calculé | Diff Argo CD entre état désiré (Git) et état réel |
| Template de release (phases, gates) | Stages GitLab CI + règles de fusion (pipeline vert obligatoire) |
| Tâche manuelle d'approbation | `when: manual` / environnement protégé GitLab |
| Audit de release | Historique Git + pipelines + événements Argo CD |

## Où chacun a sa place dans une banque

- **XL Release** gouverne le *processus* : jalons, approbations, conformité, coordination multi-équipes
  et multi-applications, y compris des systèmes non conteneurisés.
- **GitLab CI** produit et atteste l'artefact (tests, SAST, SCA, SBOM, scan d'image, DAST).
- **XL Deploy** ou **Argo CD** applique l'artefact aux environnements ; Argo CD pour les charges
  Kubernetes/OpenShift pilotées par Git, XL Deploy pour les cibles hétérogènes (VM, middleware).

Intégration typique : GitLab CI publie le package puis déclenche une release XL Release par API ;
XL Release appelle XL Deploy (ou valide la fusion GitOps) à chaque phase d'environnement.
