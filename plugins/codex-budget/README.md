# Budget Codex — Plugin

**Check your Codex budget directly in a conversation.**
**Consultez votre budget Codex directement dans une conversation.**

[English](#english) · [Français](#français)

> Looking for the desktop widget shown in screenshots? See the [Windows widget](../../codex-budget-widget/README.md).
> Vous cherchez le widget de bureau présenté en capture ? Consultez le [widget Windows](../../codex-budget-widget/README.md).

## English

Budget Codex helps you check your usage and plan your remaining budget until the next reset, without leaving your Codex conversation.

### How to use it

With the plugin available in your Codex task, ask:

> Show my Codex budget.

The plugin records a reading and shows your observed daily usage, your daily target and a suggested budget until the next reset. The default target is **15% of the weekly quota per day**. You can change it by asking:

> Set my daily limit to 12 percentage points.

One percentage point means 1% of the full weekly quota.

### What to expect

- **On-demand checks:** readings are taken when you ask; there is no permanent widget or background monitoring.
- **A growing history:** tracking begins with the first reading. Earlier daily usage cannot be recovered, and gaps around midnight are not assigned to a day without evidence.
- **Planning guidance:** targets help you pace your usage but do not block Codex or grant additional quota.
- **Local history:** readings are saved in `~/.codex-budget/history.json`, separately from the plugin cache.

### Requirements

This plugin needs a Codex task with access to the `get_usage_limits` tool, plus Python 3.10 or later. Windows also needs the `tzdata` package. This directory contains the plugin source; it is not a one-click installer.

The plugin stores usage limits, dates and a hashed account identifier. It does not access your sign-in credentials or send your history to a separate service. Figures are indicative because readings are periodic and may be rounded.

Independent project. Not an official OpenAI product.

## Français

Budget Codex vous aide à consulter votre consommation et à organiser votre budget jusqu’au prochain renouvellement, directement dans une conversation Codex.

### Comment l’utiliser

Lorsque le plugin est disponible dans votre tâche Codex, demandez :

> Montre mon budget Codex.

Le plugin enregistre un relevé et présente la consommation quotidienne observée, votre objectif journalier et un budget conseillé jusqu’au prochain renouvellement. L’objectif par défaut est de **15 % du quota hebdomadaire par jour**. Pour le modifier, demandez par exemple :

> Fixe mon plafond à 12 points par jour.

Un point correspond à 1 % du quota hebdomadaire total.

### À savoir

- **Consultation à la demande :** un relevé est pris lorsque vous le demandez, sans widget permanent ni suivi en arrière-plan.
- **Historique progressif :** le suivi commence au premier relevé. Il ne reconstitue pas les jours précédents et n’attribue pas arbitrairement à une journée la consommation autour de minuit.
- **Aide à la gestion :** les objectifs servent à répartir votre consommation. Ils ne bloquent pas Codex et n’ajoutent aucun quota.
- **Historique local :** les relevés sont conservés dans `~/.codex-budget/history.json`, en dehors du cache du plugin.

### Prérequis

Le plugin nécessite une tâche Codex disposant de l’outil `get_usage_limits`, ainsi que Python 3.10 ou plus récent. Sur Windows, le paquet `tzdata` est également nécessaire. Ce dossier contient les sources du plugin ; ce n’est pas un installateur en un clic.

Le plugin conserve les limites d’utilisation, les dates et un identifiant de compte haché. Il n’accède pas à vos identifiants de connexion et n’envoie pas votre historique à un service distinct. Les chiffres restent indicatifs, car les relevés sont ponctuels et peuvent être arrondis.

Projet indépendant, non officiel et non affilié à OpenAI.
