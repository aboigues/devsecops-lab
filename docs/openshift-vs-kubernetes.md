# De Kubernetes (Kapsule) à OpenShift

Les manifestes de `gitops/base` sont communs ; seul l'overlay change.

| Sujet | Kubernetes (lab Kapsule) | OpenShift |
|---|---|---|
| Exposition | Service (+ Ingress / Gateway API) | `Route` (overlay `openshift/route.yaml`), TLS edge |
| Sécurité des pods | Pod Security Admission `restricted` | SCC `restricted-v2` (par défaut) |
| UID du conteneur | UID de l'image (10001) | UID arbitraire imposé par le projet |
| Conséquence image | `USER 10001` suffit | Fichiers appartenant au groupe 0 et `chmod g=u` (fait dans le `Dockerfile`) |
| Namespace | `Namespace` | `Project` (namespace + annotations, quotas) |
| GitOps | Argo CD installé par Helm (Terraform) | Opérateur OpenShift GitOps (Argo CD packagé Red Hat) |
| Build | CI externe + registry | CI externe, ou `BuildConfig`/Shipwright interne |

## Pourquoi le `Deployment` ne fixe pas `runAsUser`

OpenShift attribue à chaque projet une plage d'UID et refuse un pod qui en impose un autre.
`runAsNonRoot: true` sans `runAsUser` fonctionne sur les deux plateformes : l'image démarre en
10001 sur Kubernetes, en UID arbitraire (groupe 0) sur OpenShift.

## Déployer sur OpenShift Developer Sandbox

L'image est construite **dans le cluster** : un `BuildConfig` clone ce dépôt et construit `app/Dockerfile`
(stratégie Docker, exécutée par Buildah sans privilège), puis la pousse dans l'`ImageStream` `bank-api`.
L'overlay référence `bank-api:lab` ; l'annotation `alpha.image.policy.openshift.io/resolve-names` et
`lookupPolicy.local` résolvent ce nom vers le registre interne, quel que soit le projet. Aucun registre
externe ni secret de pull n'est nécessaire.

```bash
oc login --token=<jeton> --server=<api du sandbox>     # dans son propre terminal
oc apply -k openshift/build                             # ImageStream + BuildConfig
oc start-build bank-api --follow                        # build dans le cluster
oc apply -k gitops/overlays/openshift                   # Deployment + Service + Route
oc rollout status deployment/bank-api
curl https://$(oc get route bank-api -o jsonpath='{.spec.host}')/api/accounts
```

Nettoyage : `oc delete -k gitops/overlays/openshift && oc delete -k openshift/build`.

## Validation réelle — Developer Sandbox, 25/09/2026

Exécution sur le Red Hat Developer Sandbox (OpenShift, client `oc` 4.22.14), à partir du commit `6e5d60a` de `main`.

| Vérification | Résultat observé |
|---|---|
| Build dans le cluster (`bank-api-1`, stratégie Docker) | `Complete` en 1 min 37 s, image poussée dans l'ImageStream (`bank-api@sha256:3d9c1a40...`) |
| Rollout | 2 réplicas `Running`, sondes readiness/liveness vertes |
| SCC attribuée | `restricted-v2` (aucune SCC élargie demandée) |
| Identité du processus | `uid=1013920000 gid=0(root) groups=0(root),1013920000` : UID arbitraire du projet, groupe 0 |
| Système de fichiers | `readOnlyRootFilesystem: true`, seul `/tmp` (emptyDir) inscriptible |
| `GET /api/accounts` via la Route | `200`, en-têtes `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'`, `Cache-Control: no-store` |
| Virement avec IBAN `' OR 1=1 --` | `400` (rejeté par la validation, avant le service) |
| Virement valide | `204` |
| `GET /actuator/env` | `404` (seules les sondes de santé sont exposées) |
| `http://` vers la Route | `302` vers `https://` (TLS edge, `insecureEdgeTerminationPolicy: Redirect`) |

Point de vigilance pédagogique : l'API garde ses soldes **en mémoire**, donc avec 2 réplicas
chaque pod a son propre état et un virement n'est visible que sur le pod qui l'a traité. C'est voulu
pour un lab centré sur la chaîne de livraison, et c'est un bon support pour aborder les applications
sans état (12-factor) et la persistance externe.
