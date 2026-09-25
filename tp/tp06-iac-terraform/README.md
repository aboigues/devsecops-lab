# TP06 — IaC Terraform : quand le scanner ne voit rien, on écrit ses tests

> Durée estimée : 2 h · Programme : jour 2, lab 6 · Gate : [Gate 6](../../docs/gates-securite.md#gate-6--iac--un-pod-privilégié-un-dockerfile-root)
> Prérequis : **Terraform 1.14 ou plus**, accès au registre Terraform (téléchargement du fournisseur).
> Aucun compte Scaleway nécessaire : rien n'est créé, le fournisseur est **simulé**.

## Le contexte

Un collègue a écrit le module du bastion d'administration et du bucket d'exports de la banque. Il
« marche » : `terraform plan` passe. Mais :

- `admin_cidrs` vaut par défaut `0.0.0.0/0` : **SSH ouvert au monde entier** si personne n'y pense ;
- le groupe de sécurité **accepte** par défaut tout trafic entrant ;
- le bucket d'exports (des données clients) est en `public-read` et n'est pas versionné.

Réflexe : passer un scanner d'IaC. Voici la sortie réelle de `trivy config` sur ce module (Trivy 0.74.0,
toutes sévérités) :

```
┌────────┬───────────┬───────────────────┐
│ Target │   Type    │ Misconfigurations │
├────────┼───────────┼───────────────────┤
│ .      │ terraform │         0         │
└────────┴───────────┴───────────────────┘
```

**Zéro.** Trivy embarque des centaines de règles pour AWS, Azure et Google Cloud, mais aucune ne couvre
ces ressources Scaleway.
Un scanner vert ne prouve rien s'il ne connaît pas votre fournisseur. La réponse : **écrire ses
propres garde-fous**, avec deux outils natifs de Terraform :

- les blocs `validation` : une valeur interdite est refusée **avant** tout plan ;
- `terraform test` : des assertions sur le plan, exécutées hors ligne avec un **fournisseur simulé**
  (`mock_provider`), donc sans compte, sans coût, en une seconde, dans la CI.

## Objectif vérifiable

Le module est formaté et valide, `admin_cidrs` n'a plus de valeur par défaut et refuse `0.0.0.0/0`,
`::/0` et les valeurs invalides, l'entrée est refusée par défaut, le bucket est privé et versionné.
Vos tests (au moins 3, dont un `expect_failures`) passent, **ainsi que les contrôles du formateur**
(`controles/controles.tftest.hcl`). `./verify.sh` contrôle tout cela.

---

## Étape 1 — Constater

```bash
cd starter
trivy config --severity LOW,MEDIUM,HIGH,CRITICAL .      # 0 constat
terraform init -backend=false
terraform test                                         # votre premier test échoue déjà
```

> **Question** : relisez `terraform/platform/variables.tf` à la racine du dépôt. Quelle protection de la
> vraie plateforme ce module a-t-il oubliée ?

## Étape 2 — Une variable qui se défend (TODO 1 et 2)

Dans `variables.tf` : supprimez la valeur par défaut, puis ajoutez un bloc `validation` qui refuse tout ce
qui n'est pas un CIDR valide, ainsi que `0.0.0.0/0` et `::/0`.

```bash
terraform plan -var 'admin_cidrs=["0.0.0.0/0"]'        # doit être refusé, avec votre message
```

> **Question** : pourquoi supprimer la valeur par défaut, alors que la validation refuserait de toute façon
> `0.0.0.0/0` ? (Pensez au collègue qui mettra `["10.0.0.0/8"]` « pour que ça marche ».)

## Étape 3 — Refuser par défaut, protéger le bucket (TODO 3 à 5)

- `inbound_default_policy = "drop"` : seul ce qui est explicitement autorisé passe.
- `versioning { enabled = true }` : un export écrasé ou chiffré par un rançongiciel reste récupérable.
- `acl = "private"`.

## Étape 4 — Écrire les tests (TODO 6 et 7)

Complétez `tests/securite.tftest.hcl` : un `run` qui vérifie que le bucket est privé **et** versionné, et
un `run` qui prouve que `0.0.0.0/0` est **refusé** (`expect_failures = [var.admin_cidrs]`).

```bash
terraform test
```

> **Question** : un test qui vérifie qu'une valeur interdite est **refusée** (test négatif) protège contre
> quoi, exactement ? Que se passerait-il si un collègue supprimait le bloc `validation` ?

## Étape 5 — Validez

```bash
cd ..
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

`verify.sh` ajoute les contrôles du formateur à vos tests : ils testent aussi `::/0`, une valeur
invalide, et qu'aucune règle n'ouvre le port 22 hors de `admin_cidrs`.

---

## Indices

<details>
<summary>Le bloc validation</summary>

```hcl
validation {
  condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0)) && !contains(["0.0.0.0/0", "::/0"], c)])
  error_message = "admin_cidrs doit contenir des CIDR valides, jamais 0.0.0.0/0 ni ::/0."
}
```

`cidrhost` échoue sur une valeur qui n'est pas un CIDR ; `can` transforme cet échec en `false`.
</details>

<details>
<summary>Un test positif et un test négatif</summary>

```hcl
run "le_bucket_d_exports_est_prive" {
  command = plan
  assert {
    condition     = scaleway_object_bucket_acl.exports.acl == "private"
    error_message = "ACL attendue : private."
  }
}

run "ssh_ouvert_au_monde_refuse" {
  command = plan
  variables {
    admin_cidrs = ["0.0.0.0/0"]
  }
  expect_failures = [var.admin_cidrs]
}
```
</details>

---

## Où chercher (documentation officielle)

- **Validation des variables** : https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules
- **`terraform test`** : https://developer.hashicorp.com/terraform/language/tests
- **Fournisseurs simulés (`mock_provider`)** : https://developer.hashicorp.com/terraform/language/tests/mocking
- **Groupe de sécurité Scaleway** : https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/instance_security_group
- **Trivy, couverture des scans IaC** : https://trivy.dev/latest/docs/coverage/iac/

---

## Pour aller plus loin

1. **tflint.** La CI du dépôt lance `tflint` avec `.tflint.hcl`. Lancez-le sur votre module : que
   vérifie-t-il que `terraform validate` ne vérifie pas ?
2. **Une règle Trivy maison.** Trivy accepte des règles personnalisées écrites en Rego. Écrivez-en une qui
   signale `inbound_default_policy = "accept"` sur `scaleway_instance_security_group`. Comparez l'effort
   avec un test Terraform.
3. **Le state est un secret.** Lisez `terraform/bootstrap/main.tf` : pourquoi le bucket de state est-il
   versionné, privé et verrouillé (`use_lockfile`) ? Que contient un state en clair ?
4. **Les tests dans la CI.** Ajoutez `terraform test` au job `iac` de `.github/workflows/ci.yml` pour les
   modules de `terraform/modules/`. Quels tests écririez-vous pour le module `gitlab` ?

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
