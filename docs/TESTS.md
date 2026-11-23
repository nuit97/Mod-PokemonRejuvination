# Rapport de validation — Mode Nuit 0.1.0

**143 contrôles réussis en anglais et 144 avec RejuvFR 1.1.40.** Les deux séries ont installé le ZIP publié dans une copie temporaire de Pokémon Rejuvenation **14.0.28** et ont chacune lancé deux processus Linux mkxp-z successifs. Le contrôle supplémentaire en français vérifie le chargement du catalogue RejuvFR. [Journal anglais](checks-en.txt) · [Journal français](checks-fr.txt)

Le banc utilise les scripts, les cartes compilées, les définitions de Pokémon, l’IA, le calcul des dégâts et la sérialisation du jeu. Les entrées du joueur, les dialogues graphiques et les animations sont pilotés ou remplacés pendant les tests. Il s’agit de tests automatisés dans le moteur.

| Domaine | Ce qui a été vérifié |
|---|---|
| Introduction | Choix Story, Classic et Nuit sur l’événement de la carte 001. Refuser la confirmation permet de choisir Classic. La difficulté et les mots de passe sont verrouillés après confirmation de Nuit. |
| Pokémon et objets rares | Six IV sur rencontres sauvages, dresseurs, boss généré, œuf, cadeau à IV imposés, échange avec PNJ, équipe et PC. Remise à zéro des EV et recalcul des stats. Les 21 choix de nature modifient la valeur enregistrée et effacent l’ancien indicateur. Utilisation des deux objets depuis le sac avec sélection du Pokémon. Nature et IV relus après une fermeture complète. |
| Entraînement | Gains d’EV natifs, plafonds 252/510, multiplicateur du Bracelet Macho et conditions de carte des six bornes d’accès de la carte 294. Vérification des plafonds de niveaux et des paramètres d’une équipe témoin Classic. |
| Combats | Deux duels terminés avec le moteur et son IA. Remplacement du Pokémon adverse avec un remplaçant disponible côté joueur, sans proposition de changement gratuit. Blocage du sac des deux camps et de l’utilisation d’une Potion adverse. Capture sauvage à la Master Ball, enregistrement d’une Potion en combat sauvage, Baie Sitrus, Régénérateur, Soin et Rappel hors combat. |
| Progression | Ramassage sur carte et cadeau scénarisé donnant des Hyper Balls. Conversion dans le sac, le PC, l’objet tenu et les offres en argent ou en AP. Vérification d’un Bonbon EXP, des fiches de terrain, des événements ciblés de Philip/Miikal/Lemmi et de leurs voisins. |
| Économie | Avec 500 ₽, défaite à 2 500 ₽, puis redémarrage du moteur et lecture de −2 000 ₽. Victoire à 1 000 ₽ puis sauvegarde du solde réel de −1 000 ₽. Achat refusé à découvert, vente créditée, signe négatif affiché et événements de gain ou retrait d’argent. |
| Fichiers | Identifiant d’aventure et marqueur du sélecteur. Un seul fichier Nuit sélectionnable. Protection contre les écritures dans un autre emplacement et contre les révisions obsolètes. Rejet d’un fichier temporaire endommagé. Sauvegarde après changement de carte. Rechargement du secours technique. Une autre partie Story est restée identique octet par octet et s’est rechargée avec ses IV et sa difficulté natifs. |
| Version et langue | Noms et descriptions des objets dans les deux langues. Catalogue RejuvFR installé avec le mod. Refus d’ouvrir une partie Nuit lorsque le numéro de version est simulé comme incompatible sur l’API 14.0.28. |

## Périmètre et limites

- Les sources et les événements de la version indiquée ont été examinés pour cibler les entraînements répétables. Le banc vérifie les listes de commandes des PNJ concernés et l’accès au premier combat de Lemmi. Une campagne complète permettrait de vérifier les variantes scénarisées en contexte.
- Un boss a été généré par le moteur. Ses phases, boucliers, combats doubles et partenaires de scénario n’ont pas été parcourus de bout en bout. La comparaison des équipes Classic porte sur une équipe témoin. Les fonctionnalités réseau sont hors du protocole.
- Les conditions des six portes EV ont été évaluées sur les événements compilés. Aucun parcours visuel des six salles, de la création du personnage jusqu’aux portes, n’a été enregistré.
- Aucun essai interactif sur Windows, macOS ou mobile. Le rendu des fenêtres, du symbole lunaire et des polices reste à vérifier sur une installation complète. Le temps d’écriture sur un PC lent et une coupure physique d’alimentation n’ont pas été mesurés. Les tests d’interruption couvrent le redémarrage de processus et une écriture temporaire invalide.
- RejuvFR 1.1.40 annonce une base 14.0.24. Les résultats concernent le catalogue et les chemins exercés sur 14.0.28. D’autres extensions qui remplacent les mêmes méthodes peuvent modifier leur comportement. [Projet RejuvFR](https://github.com/bss3m/RejuvFR)

## Reproduire sous Linux

Il faut une copie de Rejuvenation 14.0.28, son moteur Linux mkxp-z extrait et Python 3. Depuis la racine du dépôt, adapte les chemins. Ajouter l’argument RejuvFR lance la variante française.

```sh
python3 tests/run.py --game "/chemin/Rejuvenation" --engine "/chemin/squashfs-root/AppRun" --mod-zip dist/Mode_Nuit_0.1.0_Rejuvenation_14.0.28.zip --log controles-en.txt
python3 tests/run.py --game "/chemin/Rejuvenation" --engine "/chemin/squashfs-root/AppRun" --mod-zip dist/Mode_Nuit_0.1.0_Rejuvenation_14.0.28.zip --french "/chemin/RejuvFR_v1.1.40.zip" --log controles-fr.txt
```

Le lanceur crée un profil portable temporaire, charge les six scripts du ZIP et efface cette copie à la fin. Il compare la liste des fichiers de l’archive aux scripts attendus. L’archive publiée a aussi été décompressée et ses six entrées comparées octet par octet aux sources.

**SHA-256 du ZIP** `8378a849fe0e5857278484032cbd40b4207a2b2320f6f09a649d3be8c82744ff`.
