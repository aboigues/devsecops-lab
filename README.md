# devsecops-lab

Plateforme de formation DevSecOps **déployée à la demande** sur Scaleway par Terraform :
un GitLab auto-hébergé, son runner, un cluster Kubernetes avec Argo CD, et un environnement
isolé par apprenant. Une application Java (API bancaire Spring Boot) sert de fil rouge au
pipeline de sécurité.

Conçue et maintenue par Alexandre BOIGUES (Telemach Learning, organisme de formation certifié Qualiopi)
pour animer des formations DevSecOps sur une chaîne d'outils réelle, puis la détruire en fin de session.

## Architecture

```
                         terraform/platform (étape 1)                 terraform/labs (étape 2)
  ┌──────────────────────────────────────────────────────────┐   ┌────────────────────────────────────┐
  │  VPC privé                                               │   │ GitLab : groupe, 1 utilisateur +   │
  │  ┌───────────────────┐   ┌──────────────┐   ┌──────────┐ │   │ 1 projet par apprenant, deploy     │
  │  │ GitLab CE 19.4    │<──│ GitLab Runner│   │ Kapsule  │ │   │ token lecture, jeton GitOps        │
  │  │ + registry        │   │ Docker, non  │   │ Cilium   │ │   │                                    │
  │  │ Let's Encrypt     │   │ privilégié   │   │ 2 noeuds │ │   │ Kubernetes : Argo CD, 1 namespace  │
  │  └───────────────────┘   └──────────────┘   └──────────┘ │   │ par apprenant (PSA restricted,     │
  │  Secret Manager : mot de passe root                      │   │ NetworkPolicy), Application Argo   │
  └──────────────────────────────────────────────────────────┘   └────────────────────────────────────┘
                   state distant : Object Storage versionné (terraform/bootstrap)
```

Chaîne de livraison d'un apprenant :

```
git push ─> GitLab CI ─> tests ─> SAST / secrets / SCA+SBOM / IaC ─> image (Buildah rootless)
        ─> scan image ─> DAST (ZAP) ─> commit du tag dans gitops/ ─> Argo CD synchronise le namespace
```

La CI ne détient **aucun identifiant du cluster** : elle met à jour l'état désiré dans Git, Argo CD le tire.

## Contenu

| Chemin | Rôle |
|---|---|
| `terraform/bootstrap` | Bucket de state distant (versionné, privé) |
| `terraform/platform` | VPC, GitLab (module), runner (module), Kapsule (module), secrets |
| `terraform/labs` | Configuration GitLab + Argo CD + environnements apprenants (`for_each`) |
| `app/` | API Spring Boot 4.1 / Java 25 : pyramide de tests, couverture JaCoCo >= 80 %, image non-root compatible OpenShift |
| `gitops/` | Manifestes Kustomize durcis ; overlays `lab` (Kapsule) et `openshift` (Route) |
| `.gitlab-ci.yml` | Pipeline de référence |
| `Jenkinsfile`, `bitbucket-pipelines.yml` | Mêmes contrôles sur Jenkins et Bitbucket |
| `docs/` | Comparatif CI, OpenShift, XL Deploy/Release, programme de formation |

## Déployer une session

Prérequis : Terraform >= 1.14 et identifiants Scaleway, soit via un profil de la CLI `scw`
(`export SCW_PROFILE=<profil>`), soit via `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`, `SCW_DEFAULT_PROJECT_ID`.

```bash
# 0. Une seule fois : bucket de state
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply -var bucket_name=devsecops-lab-tfstate-<suffixe>
cp terraform/backend.hcl.example terraform/backend.hcl        # bucket + clés S3

# 1. Plateforme (~15 min : GitLab Omnibus + certificats + cluster)
cp terraform/platform/terraform.tfvars.example terraform/platform/terraform.tfvars
terraform -chdir=terraform/platform init -backend-config=../backend.hcl
terraform -chdir=terraform/platform apply

# 2. Environnements apprenants
cp terraform/labs/terraform.tfvars.example terraform/labs/terraform.tfvars
terraform -chdir=terraform/labs init -backend-config=../backend.hcl
terraform -chdir=terraform/labs apply
terraform -chdir=terraform/labs output -json learner_credentials

# Fin de session : tout détruire, dans l'ordre inverse
terraform -chdir=terraform/labs destroy
terraform -chdir=terraform/platform destroy
```

Coût indicatif (tarifs Scaleway fr-par, septembre 2026) : GitLab DEV1-XL ~0,065 EUR/h, runner DEV1-L
~0,043 EUR/h, 2 noeuds DEV1-M, plan de contrôle Kapsule mutualisé gratuit : **environ 0,15 EUR/h**,
soit moins de 4 EUR pour une session de 3 jours laissée allumée en continu.

## Choix de sécurité

- **Moindre privilège des jetons** : Terraform génère deux PAT distincts injectés au premier démarrage de
  GitLab : `api` pour l'étape 2, `create_runner` seul pour la VM runner. Les fichiers de bootstrap sont
  détruits (`shred`) après usage. Les jetons expirent à 30 jours.
- **Réseau** : politique d'entrée par défaut `drop` ; SSH limité à `admin_cidrs` (0.0.0.0/0 refusé par
  validation) ; seuls 80 (ACME) et 443 sont publics sur GitLab ; le runner n'expose rien.
- **Runner non privilégié** : pas de Docker-in-Docker ; images construites par Buildah rootless.
- **Kubernetes** : Pod Security Admission `restricted`, NetworkPolicy par namespace, conteneur non-root,
  système de fichiers en lecture seule, capacités supprimées, seccomp `RuntimeDefault`.
- **State Terraform** : il contient des secrets ; bucket privé, versionné, verrouillage natif (`use_lockfile`).
- **Contrôles bloquants** : HIGH/CRITICAL corrigeables sur dépendances et image, MEDIUM+ sur l'IaC,
  toute alerte ZAP, couverture < 80 %.

## Limites connues (assumées pour un lab)

- Tant que le premier pipeline d'un apprenant n'a pas tourné, son application Argo CD pointe vers une
  image fictive (`registry.example.invalid`) : état `ImagePullBackOff` attendu.
- GitLab mono-instance sans sauvegarde : l'environnement est éphémère par conception.
- En édition CE, les rapports SAST/secrets sont des artefacts ; la vue « Security dashboard » relève d'Ultimate.
- `sslip.io` et Let's Encrypt évitent de gérer un domaine, mais sont soumis aux quotas Let's Encrypt.
