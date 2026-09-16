$script:english = @{
 "Encore {0} % disponibles aujourd’hui"="{0}% still available today"
 "Consommé aujourd’hui : au moins {0} % · relevé incomplet"="Used today: at least {0}% · incomplete history"
 "Jours restants"="Days left"
 "Jours travaillés restants avant le reset, aujourd’hui inclus"="Working days before reset, including today"
 "Quota restant réparti jusqu’au reset"="Remaining quota shared until reset"
 "Le quota réel restant est partagé entre les jours travaillés avant le reset. La consommation passée est déjà déduite : aucun malus supplémentaire."="Actual remaining quota is shared across working days before reset. Past usage is already deducted: no extra deficit."
 "Moyenne semaine : {0} % / jour travaillé"="Weekly average: {0}% / working day"
 "Moyenne : une journée travaillée nécessaire"="Average: one working day needed"
 "Demain à ce rythme"="Tomorrow at this pace"
 "Estimation du budget disponible demain si le rythme moyen continue jusqu’à ce soir. Le jour en cours est pondéré par le temps écoulé ; les jours de repos ne créent pas de consommation prévue."="Estimated budget available tomorrow if the average pace continues until tonight. Today is weighted by elapsed time; no additional usage is assumed on days off."
 "Demain"="Tomorrow"
 "Demain · repos"="Tomorrow · day off"
 "Si vous ne consommez plus aujourd’hui"="If you stop using quota today"
 "Reset avant demain · nouveau quota à confirmer"="Reset before tomorrow · new quota pending"
 "Mis à jour à {0} · toutes les 15 s"="Updated {0} · every 15 s"
 "Budget du jour"="Daily budget"
 "Quota hebdomadaire"="Weekly quota"
 "épuisé"="used up"
 "Jour de repos"="Day off"
 "Il reste {0} % sur la semaine"="You still have {0}% left this week"
 "En attente du renouvellement hebdomadaire"="Waiting for the weekly reset"
 "Budget sans historique de compte"="Budget without account history"
 "Diagnostic"="Diagnostics"
 "Copier le rapport"="Copy report"
 "À joindre à votre signalement de bug"="Include this report with your bug report"
 "Source choisie"="Selected source"
 "Recherche de Codex"="Finding Codex"
 "Connexion établie"="Connected"
 "Lecture des quotas"="Reading quotas"
 "Quotas reçus"="Quotas received"
 "Quota indisponible"="Quota unavailable"
 "Erreur"="Error"
 "En attente du premier diagnostic…"="Waiting for the first diagnostic…"
 "Copié !"="Copied!"
 "Copie impossible"="Could not copy"
 "Automatique"="Automatic"
 "Source des quotas"="Quota source"
 "Choix enregistré automatiquement"="Selection saved automatically"
 "Connexion à la source choisie…"="Connecting to selected source…"
 "Codex introuvable dans la distribution choisie"="Codex not found in selected distribution"
 "Choisissez une source dans les réglages"="Choose a source in settings"
 "Dans WSL : lancez codex login"="In WSL: run codex login"
 "Codex absent · Windows ou WSL"="Codex missing · Windows or WSL"
 "Compte déconnecté · lancez codex login"="Signed out · run codex login"
 "Clé API · quota ChatGPT indisponible"="API key · ChatGPT quota unavailable"
 "Lecture impossible · vérifiez Codex et la connexion"="Cannot refresh · check Codex and connection"
 "Spark : limite 5 h atteinte · attendre le reset"="Spark: 5-hour limit reached · wait for reset"
 "Spark · 5 h restantes"="Spark · 5-hour quota left"
 "Limite 5 h indisponible"="5-hour limit unavailable"
 "Quota Spark indisponible · réessaie plus tard"="Spark quota unavailable · try again later"
 "Choisis au moins un jour travaillé."="Choose at least one working day."
 "Planning enregistré · recalcul en cours…"="Schedule saved · recalculating…"
 "Enregistrement impossible · réessaie dans un instant."="Could not save · please try again."
 "Utilisé aujourd’hui"="Used today"
 "Disponible aujourd’hui"="Available today"
 "Données indisponibles · nouvelle tentative automatique"="Data unavailable · retrying automatically"
 "Hors ligne"="Offline"
 "Budget disponible épuisé pour ce jour"="Your daily budget is used up"
 "Malus"="Deficit"
 "Budget du jour réduit par le malus reporté"="Daily budget reduced by carried deficit"
 "Le report positif augmente le budget ; le malus le réduit jusqu’au reset hebdomadaire."="Positive carryover increases your budget; a deficit reduces it until the weekly reset."
 "Bientôt la limite du jour · bonus inclus"="Near your daily limit · bonus included"
 "Budget total du jour, bonus inclus"="Total daily budget, including bonus"
 "Jour de repos · utilisation du bonus uniquement"="Day off · using carryover only"
 "Solde du planning − consommation globale"="Planned allowance − total usage"
 "Budget débloqué depuis le reset selon les jours cochés, moins toute la consommation du cycle. Le détail consommé depuis minuit reste inconnu."="Allowance unlocked since reset on selected days, minus total cycle usage. Usage since midnight is not known."
 "Réglages"="Settings"
 "Réduire"="Minimize"
 "Fermer"="Close"
 "Par jour"="Per day"
 "Bonus"="Bonus"
 "Quota global restant"="Weekly quota left"
 "Jours travaillés"="Working days"
 "Appliquer"="Apply"
 "Actualiser"="Refresh"
 "Toujours au premier plan"="Always on top"
 "Connexion…"="Connecting…"
 "Premier relevé en cours…"="Waiting for the first reading…"
 "Quota hebdomadaire : —"="Weekly quota: —"
 "Reset : —"="Reset: —"
 "Bonus reporté encore disponible. Le total du jour inclut le bonus du début de journée."="Unused carryover still available. The daily total includes the opening bonus."
 "Quota hebdomadaire : {0} % restants"="Weekly quota: {0}% remaining"
 "Reset : {0} · heure locale"="Reset: {0} · local time"
 "Mis à jour à {0} · toutes les minutes"="Updated {0} · every minute"
 "Impossible de mémoriser la langue."="Could not save the language."
 "BudgetMonitor.exe absent."="BudgetMonitor.exe is missing."
}
function Get-Language($override) {
 if ($override -in @('fr','en')) { return $override }
 try { $savedLanguage=(Get-Content (Join-Path $dataDir 'language.json') -Raw -Encoding UTF8 | ConvertFrom-Json).language; if ($savedLanguage -in @('fr','en')) { return $savedLanguage } } catch {}
 if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'fr') { return 'fr' }
 return 'en'
}
function T([string]$key) {
 if ($script:language -eq 'en' -and $script:english.ContainsKey($key)) { return $script:english[$key] }
 return $key
}
function Get-DisplayCulture {
 if ($script:language -eq 'en') { return [Globalization.CultureInfo]::GetCultureInfo('en-GB') }
 return [Globalization.CultureInfo]::GetCultureInfo('fr-FR')
}
function Set-Language([string]$value, [switch]$Persist) {
 if ($value -notin @('fr','en')) { return }
 if ($Persist) {
  $file=Join-Path $dataDir 'language.json'
  $tmp=$file+'.tmp'
  try {
   [IO.File]::WriteAllText($tmp,(@{language=$value}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
   if (Test-Path $file) { [IO.File]::Replace($tmp,$file,$file+'.bak') } else { [IO.File]::Move($tmp,$file) }
  } catch { $ui.Context.Text=(T 'Impossible de mémoriser la langue.'); return }
 }
 $script:language=$value
 Update-SourceChoices
 $ui.DiagnosticLabel.Text=(T 'Diagnostic')
 $ui.DiagnosticHint.Text=(T 'À joindre à votre signalement de bug')
 $ui.CopyDiagnostic.Content=(T 'Copier le rapport')
 Update-Diagnostic
 foreach ($code in @('fr','en')) {
  $button=$ui[('Lang'+$code.ToUpper())]
  $button.Background=if ($value -eq $code) { '#303842' } else { 'Transparent' }
  $button.Foreground=if ($value -eq $code) { '#6DE0B9' } else { '#AFBBC8' }
  [Windows.Automation.AutomationProperties]::SetHelpText($button, $(if ($value -eq $code) { $(if ($value -eq 'fr') { 'Sélectionné' } else { 'Selected' }) } else { '' }))
 }
 $ui.DailyLabel.Text=(T "Par jour")
 $ui.BonusLabel.Text=(T "Bonus")
 $ui.GlobalLabel.Text=(T "Quota global restant")
 $ui.DaysLabel.Text=(T "Jours travaillés")
 $ui.Pin.Content=(T "Toujours au premier plan")
 $ui.SaveDays.Content=(T "Appliquer")
 $ui.Refresh.Content=(T "Actualiser")
 $ui.Bonus.ToolTip=(T "Bonus reporté encore disponible. Le total du jour inclut le bonus du début de journée.")
 $ui.UsageLabel.Text=(T "Utilisé aujourd’hui")
 $ui.Status.Text=(T "Connexion…")
 $ui.Context.Text=(T "Premier relevé en cours…")
 $ui.Weekly.Text=(T "Quota hebdomadaire : —")
 $ui.Reset.Text=(T "Reset : —")
 $ui.SettingsButton.ToolTip=(T "Réglages"); [Windows.Automation.AutomationProperties]::SetName($ui.SettingsButton,(T "Réglages"))
 $ui.Minimize.ToolTip=(T "Réduire"); [Windows.Automation.AutomationProperties]::SetName($ui.Minimize,(T "Réduire"))
 $ui.Close.ToolTip=(T "Fermer"); [Windows.Automation.AutomationProperties]::SetName($ui.Close,(T "Fermer"))
 $short=if ($value -eq 'en') { @('Mon','Tue','Wed','Thu','Fri','Sat','Sun') } else { @('Lun','Mar','Mer','Jeu','Ven','Sam','Dim') }
 $full=if ($value -eq 'en') { @('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday') } else { @('Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche') }
 for ($i=0;$i -lt $dayBoxes.Count;$i++) {
  $dayBoxes[$i].Content=$short[$i]; $dayBoxes[$i].ToolTip=$full[$i]
  [Windows.Automation.AutomationProperties]::SetName($dayBoxes[$i],$full[$i])
 }
 if ($null -ne $script:lastState) { Show-State $script:lastState }
 if ($null -ne $script:pendingDays) { $ui.Context.Text=(T 'Planning enregistré · recalcul en cours…') }
}
