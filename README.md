# Pokémon Rejuvenation — Mode Nuit ☾

Une troisième difficulté pour **Pokémon Rejuvenation 14.0.28**, imaginée par **Nuit**. Construis ton équipe avec les IV, les EV et les natures que tu veux. Face aux dresseurs, les changements de Pokémon et les défaites ont un coût.

**[Télécharger le Mode Nuit 0.1.0 (ZIP)](https://github.com/nuit97/Mod-PokemonRejuvination/raw/refs/heads/main/dist/Mode_Nuit_0.1.0_Rejuvenation_14.0.28.zip)** · [Rapport de tests](docs/TESTS.md) · [Historique](CHANGELOG.md)

## Installer

1. Installe le jeu complet et vérifie que sa version est **14.0.28**. [Téléchargement officiel](https://rejuvenationgame.com/download)
2. Ferme le jeu. Pour jouer en français, installe d’abord **RejuvFR** selon son guide. Pour jouer en anglais, passe directement à l’étape suivante. [Traduction et installation](https://github.com/bss3m/RejuvFR)
3. Extrais le ZIP du Mode Nuit **dans le dossier du jeu**, à côté de `Game.exe` sous Windows. Fusionne le dossier `patch` avec celui qui existe. Vérifie la présence de `patch/Mods/zz_mode_nuit.rb` et de `patch/ModeNuit/rules.rb`.
4. Lance une **nouvelle partie**, choisis **Mode Nuit** dans l’introduction et confirme. En anglais, l’option s’appelle **Night Mode**. Une partie existante Story ou Classic garde ses règles.

## Les règles en jeu

| Règle | Effet |
|---|---|
| Combats | Base Classic et style Défini. Quand le dresseur envoie son Pokémon suivant, tu gardes le tien sur le terrain. |
| Sac | Fermé pour les deux camps contre les dresseurs. Tu peux utiliser des objets ou capturer en combat sauvage. Les objets tenus, talents, capacités et soins hors combat suivent les règles du jeu. |
| IV et EV | Six IV à 31 pour tous les Pokémon, adversaires compris. Les EV se gagnent normalement. Le départ donne les six cartes des salles EV et le Bracelet Macho. Les cartes fonctionnent une fois sur place. |
| Outils réutilisables | Dans les Objets rares, le **Réinitialiseur d’EV** remet les six EV à zéro. La **Boîte à Menthes** permet de choisir la véritable nature parmi 20 effets et une option neutre. |
| Progression | Les Super Bonbons distribués deviennent des Hyper Balls. Dans les boutiques, la monnaie et le tarif de l’offre sont conservés. Les Bonbons EXP et les plafonds par badge suivent Classic. Les entraînements répétables identifiés où les adversaires se mettent K.O. sont fermés. |
| Terrains et réglages | Les fiches des terrains sont accessibles intégralement via l’application du jeu. La difficulté et les mots de passe sont verrouillés. Les réglages de confort restent disponibles. |
| Argent | Perdre contre un dresseur retire le montant de sa récompense positive, même si le solde passe sous zéro. Exemple testé en combat dans le moteur du jeu : 500 ₽, puis −2 000 ₽ après une défaite à 2 500 ₽, puis −1 000 ₽ après une victoire à 1 000 ₽. Une vente ou un gain de scénario recrédite ce même solde. |

Les combats sans prime, notamment ceux d’installations à score et ceux de certains personnages invités, n’imputent aucune prime au héros. Quand un contrat de chance fait payer la victoire, la prime positive vaut zéro. Une défaite sauvage et un match nul conservent la perte Classic dans la limite de l’argent disponible.

## Sauvegarde et reprise

Chaque aventure Nuit dispose d’un emplacement actif marqué **☾ MODE NUIT**. Le jeu enregistre la pénalité avant de rendre la main. Si tu quittes pendant la fin du combat, tu peux reprendre au dernier point de carte sûr avec la pénalité déjà déduite. Le point complet suivant s’écrit lorsque le jeu revient sur une carte stable. La sauvegarde manuelle utilise le même emplacement.

Pour un fichier endommagé, ferme le jeu et copie le dossier de sauvegardes ailleurs. Dans ce dossier, repère le fichier actif de la partie, par exemple `Game_3.rxdata`. Conserve le fichier endommagé sous un autre nom. Copie **le secours du même emplacement** (`Game_3.rxdata.nuit-secours`) sous le nom actif (`Game_3.rxdata`), puis relance le jeu. Ce secours correspond à l’écriture valide précédente et apparaît après la deuxième écriture. Une copie externe reste techniquement possible.

## Désinstaller ou mettre le jeu à jour

Ferme le jeu. Retire uniquement `patch/Mods/zz_mode_nuit.rb` et le dossier `patch/ModeNuit/`. Garde les sauvegardes et les autres fichiers du dossier `patch`. Tes parties Story et Classic peuvent continuer. Pour reprendre une partie Nuit, conserve une installation 14.0.28 avec le mod. Charger puis enregistrer cette partie sans le mod peut lui faire perdre ses règles.

## Compatibilité vérifiée

Première version publique testée dans le moteur Linux, en anglais et avec **RejuvFR 1.1.40**. La traduction annonce cibler **14.0.24**. Les vérifications en 14.0.28 couvrent les règles et les nouveaux textes utilisés dans les tests. Le rendu sur Windows, les autres mods et une campagne complète restent à valider. [Tests et limites](docs/TESTS.md)

Le ZIP contient six scripts Ruby. Le jeu, ses ressources et la traduction s’obtiennent séparément. [Crédits et distribution](docs/CREDITS.md) · [Licence du mod](LICENSE)
