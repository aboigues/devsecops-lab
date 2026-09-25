# TP08 — Kubernetes : un pod qui passe l'admission « restricted »

> Durée estimée : 1 h 30 · Programme : jour 3, lab 9 · Gate : [Gate 6](../../docs/gates-securite.md#gate-6--iac--un-pod-privilégié-un-dockerfile-root)
> Prérequis : **Trivy 0.74** (`tp/scripts/installer-outils.sh`), `yq` v4. Aucun cluster nécessaire.

## Le contexte

Le micro-service « soldes » (celui du TP05) doit être déployé dans le cluster partagé de la banque.
Son `deployment.yaml` a été copié d'un vieux tutoriel : il tourne en **mode privilégié**. Un conteneur
privilégié voit les périphériques de l'hôte ; une faille applicative devient une **compromission du
nœud**, donc de tous les autres services (dans le lab : de tous les autres apprenants).

Deux lignes de défense, comme sur la plateforme du dépôt :

1. **En CI** : `trivy config` refuse le manifeste avant qu'il n'atteigne le cluster.
2. **À l'admission** : le namespace impose le profil Pod Security **restricted**. Même si quelqu'un
   contourne la CI (`kubectl apply` à la main), le cluster refuse le pod. C'est la **défense en profondeur**.

## Objectif vérifiable

`trivy config` ne trouve aucun défaut MEDIUM ou plus (exception éventuelle ciblée et justifiée), le
namespace impose `restricted`, le pod et le conteneur sont durcis, les ressources sont bornées, et le
réseau est fermé par défaut, seul le port 8080 restant ouvert. `./verify.sh` contrôle tout cela.

---

## Étape 1 — Mesurer

```bash
cd starter
trivy config --severity MEDIUM,HIGH,CRITICAL .
```

Sortie réelle (Trivy 0.74.0) :

```
Failures: 8 (MEDIUM: 5, HIGH: 3, CRITICAL: 0)
KSV-0001 (MEDIUM): Container 'soldes' of Deployment 'soldes' should set 'securityContext.allowPrivilegeEscalation' to false
KSV-0012 (MEDIUM): Container 'soldes' of Deployment 'soldes' should set 'securityContext.runAsNonRoot' to true
KSV-0013 (MEDIUM): Container 'soldes' of Deployment 'soldes' should specify an image tag
KSV-0014 (HIGH): Container 'soldes' of Deployment 'soldes' should set 'securityContext.readOnlyRootFilesystem' to true
KSV-0017 (HIGH): Container 'soldes' of Deployment 'soldes' should set 'securityContext.privileged' to false
KSV-0104 (MEDIUM): container "soldes" of deployment "soldes" in "soldes" namespace should specify a seccomp profile
KSV-0118 (HIGH): deployment soldes in soldes namespace is using the default security context, which allows root privileges
KSV-0125 (MEDIUM): Container soldes in deployment soldes (namespace: soldes) uses an image from an untrusted registry.
```

## Étape 2 — Le namespace (TODO 1)

Ajoutez les labels Pod Security Admission : `pod-security.kubernetes.io/enforce: restricted` (et, c'est
recommandé, `warn` et `audit` au même niveau).

> **Question** : `enforce`, `warn`, `audit` : que fait chacun ? Pourquoi commencer par `warn` sur un cluster
> existant avant de passer à `enforce` ?

## Étape 3 — Le pod et le conteneur (TODO 2 à 6)

| Niveau | Réglage | Pourquoi |
|---|---|---|
| Pod | `automountServiceAccountToken: false` | Pas de jeton d'API Kubernetes offert à un attaquant |
| Pod | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | Pas de root, appels système filtrés |
| Conteneur | `privileged: false`, `allowPrivilegeEscalation: false` | Pas d'accès à l'hôte, pas de `setuid` |
| Conteneur | `readOnlyRootFilesystem: true` + `emptyDir` sur `/tmp` | Un attaquant ne peut rien déposer dans l'image |
| Conteneur | `capabilities.drop: ["ALL"]` | Aucune capacité Linux |
| Conteneur | image `:1.0.0`, `resources` | Version connue ; un pod ne peut pas affamer le nœud |

Comparez avec `gitops/base/deployment.yaml` à la racine du dépôt.

## Étape 4 — Le réseau (TODO 7)

Créez `networkpolicy.yaml` avec deux politiques : une qui **refuse tout** (podSelector vide, `Ingress` et
`Egress`, aucune règle), et une qui n'ouvre **que** le port 8080 du service, depuis le namespace de l'ingress.

> **Question** : avec `Egress` refusé par défaut, le pod peut-il encore résoudre un nom DNS ? Que faudrait-il
> ajouter si le service devait appeler une API externe ?

## Étape 5 — Trier le dernier constat (TODO 8)

Il reste **KSV-0125** : l'image vient de `ghcr.io/neobanque-exemple`, que la liste de confiance **générique**
de Trivy ne peut pas connaître. Vrai problème ou faux positif **dans ce contexte** ? Si vous décidez d'une
exception, elle doit être **ciblée** (cet identifiant seul), **datée** et **justifiée** avec une mesure
compensatoire, dans un `.trivyignore` du dossier. C'est exactement ce que fait le dépôt à sa racine
(`.trivyignore`, consigné dans `docs/journal-securite.md`).

> **Question** : pourquoi `verify.sh` refuse-t-il une exception sans commentaire, ou une exception sur
> KSV-0017 (conteneur privilégié) ?

## Étape 6 — Validez

```bash
cd ..
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

---

## Indices

<details>
<summary>securityContext complet</summary>

```yaml
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: soldes
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
```
</details>

<details>
<summary>NetworkPolicy « tout refuser »</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tout-refuser
  namespace: soldes
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```
</details>

<details>
<summary>Une exception tracée</summary>

```
# KSV-0125 (registre hors liste de confiance Trivy) - AAAA-MM-JJ
# Pourquoi c'est acceptable ici, et la mesure compensatoire.
KSV-0125
```
</details>

---

## Où chercher (documentation officielle)

- **Pod Security Standards** : https://kubernetes.io/docs/concepts/security/pod-security-standards/
- **Pod Security Admission** : https://kubernetes.io/docs/concepts/security/pod-security-admission/
- **NetworkPolicy** : https://kubernetes.io/docs/concepts/services-networking/network-policies/
- **Contrôles Kubernetes de Trivy** : https://avd.aquasec.com/misconfig/kubernetes/
- **OpenShift, SCC** : https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/authentication_and_authorization/managing-pod-security-policies

---

## Pour aller plus loin

1. **L'admission pour de vrai.** Créez un cluster local avec `kind`, appliquez `solution/namespace.yaml`,
   puis `starter/deployment.yaml` : lisez le refus (`violates PodSecurity "restricted:latest"`). Appliquez
   ensuite `solution/deployment.yaml`.
2. **Kyverno.** Remplacez l'exception KSV-0125 par une politique Kyverno qui n'autorise dans le cluster que
   les images de `ghcr.io/neobanque-exemple`. Pourquoi est-ce une meilleure mesure qu'une exception de scanner ?
3. **OpenShift.** Comparez avec `gitops/overlays/openshift` et `docs/openshift-vs-kubernetes.md` : que fait
   la SCC `restricted-v2` que PSA ne fait pas (UID attribué par le namespace) ?
4. **Le lab des apprenants.** Retrouvez dans `terraform/labs` où la plateforme pose les labels PSA et la
   NetworkPolicy de chaque namespace apprenant.

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
