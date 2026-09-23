# Un même pipeline DevSecOps sur trois moteurs CI

Support pédagogique : les contrôles sont identiques, seule la syntaxe change.
Objectif apprenant : savoir lire et transposer un pipeline, quel que soit l'outil imposé par l'entreprise.

| Notion | GitLab CI (`.gitlab-ci.yml`) | Jenkins (`Jenkinsfile`) | Bitbucket (`bitbucket-pipelines.yml`) |
|---|---|---|---|
| Modèle | YAML déclaratif, stages + jobs | Groovy déclaratif, stages + steps | YAML déclaratif, steps |
| Exécution | Runner (executor Docker) | Agent (ici conteneurs via Docker Pipeline) | Conteneur par step, hébergé Atlassian |
| Parallélisme | Jobs d'un même stage | `parallel { }` | `parallel:` |
| Réutilisation | `extends`, `include: template` | Shared Libraries | Ancres YAML `&` / `*` |
| Secrets | Variables CI masquées/protégées | Credentials + `withCredentials` | Variables de dépôt sécurisées |
| Rapports | `artifacts:reports` (junit, coverage, cyclonedx) | Plugins JUnit, Coverage | Artefacts, onglet Tests |
| SAST / secrets intégrés | Templates GitLab (Semgrep, secret detection) | À outiller (Semgrep, gitleaks) | À outiller (Semgrep, gitleaks) |
| Construction d'image | Buildah rootless (runner non privilégié) | Docker de l'agent | Service `docker` |
| Déploiement | Commit GitOps -> Argo CD | Idem | Idem + `deployment:` (environnements) |

## Points d'attention à faire découvrir aux apprenants

1. **Jenkins** : le socket Docker monté dans un conteneur équivaut à un accès root sur l'agent. En
   environnement bancaire, préférer des agents éphémères (Kubernetes plugin) et Buildah/Kaniko.
2. **Épinglage** : toutes les images d'outils sont versionnées ; une image `latest` dans un pipeline de
   sécurité rend le résultat non reproductible et ouvre la porte à la compromission de la chaîne.
3. **Seuils** : un contrôle qui ne bloque jamais n'est pas un contrôle. On bloque sur HIGH/CRITICAL
   corrigeables, on trace le reste (SBOM), on documente toute exception.
4. **Séparation CI / CD** : la CI produit et atteste un artefact ; le déploiement est tiré par Argo CD.
   Le cluster n'est jamais exposé aux identifiants de la CI.
