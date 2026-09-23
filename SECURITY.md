# Politique de sécurité

## Signaler une vulnérabilité

Merci de ne pas ouvrir d'issue publique. Utiliser le signalement privé de GitHub :
onglet **Security** > **Report a vulnerability**. Réponse sous 5 jours ouvrés.

## Périmètre

Ce dépôt est une plateforme de formation : l'API bancaire est volontairement simple, mais la chaîne
(Terraform, pipelines, manifestes) est traitée comme du code de production. Sont dans le périmètre :
fuite de secret, contournement d'une gate de la CI, configuration Terraform ou Kubernetes exploitable,
vulnérabilité de l'application.

## Contrôles en place

Voir [`docs/gates-securite.md`](docs/gates-securite.md) : chaque gate, ce qu'elle bloque, et un exemple
réel de blocage.
