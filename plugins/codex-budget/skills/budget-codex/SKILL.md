---
name: budget-codex
description: Afficher le budget quotidien Codex, enregistrer un relevé des limites du compte et comparer la consommation observée à un plafond de 15 points par jour jusqu'au reset.
---

# Budget Codex

Utiliser ce suivi à la demande pour les limites Codex du compte connecté. Le plafond par défaut est 15 points du quota hebdomadaire par jour civil, fuseau Europe/Paris. Ce n'est pas 15 % du quota restant.

1. Lire les limites actuelles avec l'outil Codex `get_usage_limits` (le découvrir si nécessaire). Si indisponible, expliquer que le suivi ne peut pas être actualisé ; ne pas lire les fichiers d'authentification ni inventer des chiffres.
2. Enregistrer la réponse JSON de l'outil dans un fichier temporaire avec un outil d'écriture structuré. Le script accepte le payload ou l'enveloppe MCP `content`. Ne pas interpoler le JSON dans une commande shell. Supprimer ce fichier temporaire après usage : il peut contenir un identifiant de compte.
3. Exécuter `scripts/budget.py --input <fichier> --state <historique>`, chemin du script relatif à la racine du plugin (deux niveaux au-dessus de ce SKILL.md). Utiliser Python 3.10+ avec tzdata sur Windows ; localiser un runtime existant. Le fichier d'historique persistant par défaut est `~/.codex-budget/history.json`, hors du cache du plugin. Respecter les permissions d'écriture ; si ce chemin n'est pas accessible, employer un chemin autorisé et annoncer son emplacement pour les prochains relevés.
4. Afficher le rapport français renvoyé, en conservant ses mentions « partiel », « non attribué » et la date du relevé. Le suivi commence au premier relevé ; les valeurs sont arrondies par Codex. Ne jamais présenter la consommation hebdomadaire comme celle d'aujourd'hui. Une absence de données n'est pas une consommation nulle.

`--daily-cap 15` est le défaut ; une valeur explicitement fournie est conservée dans l'historique. `--timezone Europe/Paris` définit le jour civil. `--bucket codex` choisit le quota ; les autres modèles ne sont pas additionnés. Le script choisit la fenêtre de sept jours du bucket. Pour afficher un relevé enregistré sans lecture réseau : `--state <historique>` seul, en précisant qu'il n'est pas actualisé.

Le budget conseillé répartit le quota restant sur les jours civils jusqu'au reset, jour en cours inclus, et reste plafonné au maximum quotidien. C'est un repère prudent, pas une garantie : le dernier jour peut être partiel, les périodes non mesurées restent inconnues.

Ce plugin fonctionne à la demande et ne bloque pas Codex. Ne pas promettre de compteur permanent dans l'interface ou de relevés automatiques. Si l'utilisateur demande un suivi programmé, utiliser l'outil d'automatisation Codex disponible, avec le même historique ; signaler que les relevés eux-mêmes consomment du quota. Ne notifier que les changements utiles ou le franchissement d'un seuil demandé.
