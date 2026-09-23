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

```bash
oc login --token=<jeton> --server=<api du sandbox>
# Image publique du pipeline (ou registry interne OpenShift)
kustomize edit set image bank-api=<registry>/bank-api:<tag>   # dans gitops/overlays/openshift
oc apply -k gitops/overlays/openshift
oc get route bank-api -o jsonpath='{.spec.host}'
```
