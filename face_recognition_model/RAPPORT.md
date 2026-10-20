# Rapport détaillé du projet — Smart Medicine Box Face Recognition Service

## 1. Résumé

Ce dépôt contient un microservice Python autonome de vérification faciale. Il est conçu pour être appelé sur le réseau local par un backend Node.js et/ou un Raspberry Pi dans le cadre du projet « Smart Medicine Box ». Le service reçoit une image de référence et une image de contrôle, détecte un visage dans chacune avec InsightFace, compare leurs vecteurs de caractéristiques et renvoie un score ainsi qu'un résultat vrai/faux.

Le service ne gère pas lui-même les utilisateurs, les comptes, les boîtes à médicaments ou les autorisations métier. Il expose uniquement une vérification faciale et un contrôle de santé. Le dépôt observé ne contient ni documentation de déploiement, ni tests, ni fichiers Docker, ni code du backend appelant.

## 2. Objectif et périmètre

### Objectif

Fournir un service HTTP local qui répond à la question : « Le visage de l'image de contrôle ressemble-t-il suffisamment au visage de référence ? »

### Dans le périmètre

- API HTTP avec FastAPI.
- Chargement au démarrage du modèle InsightFace `buffalo_l` avec exécution CPU ONNX Runtime.
- Réception des images par formulaire multipart.
- Décodage JPEG, PNG ou WEBP via OpenCV.
- Validation d'un seul visage par image.
- Comparaison des embeddings par similarité cosinus normalisée.
- Réponses JSON et erreurs structurées.
- Limite configurable de taille par image.

### Hors périmètre observé

- Enrôlement ou stockage de profils et d'embeddings.
- Authentification, gestion de sessions ou contrôle des droits.
- Capture caméra, interface utilisateur, base de données et logique de distribution des médicaments.
- Chiffrement TLS, quotas, limitation de débit ou journal d'audit persistant.

## 3. Architecture

```text
Client local (Raspberry Pi / backend Node.js)
              |
              | HTTP multipart: reference_image + probe_image
              v
        FastAPI — app/main.py
              |
              +--> Validation des tailles et gestion des erreurs
              |
              v
        FaceEngine — app/face_engine.py
              |
              +--> OpenCV: décodage en image BGR
              +--> InsightFace buffalo_l: détection et embedding
              +--> Similarité cosinus normalisée et seuil
              |
              v
        Réponse JSON: verified, similarity, threshold
```

Les réglages sont centralisés dans `app/config.py`. Les modèles de réponse et de validation sont définis dans `app/schemas.py`. `get_face_engine()` fournit une instance singleton en mémoire afin que le modèle soit chargé une fois et réutilisé entre les requêtes.

## 4. Parcours d'une vérification

1. Le client envoie une requête `POST /face/verify` contenant les champs multipart `reference_image` et `probe_image`.
2. L'endpoint lit la configuration et vérifie que le moteur est chargé. Sinon, il répond avec le statut HTTP 503 et le code `FACE_ENGINE_NOT_READY`.
3. Chaque fichier est lu jusqu'à `FACE_MAX_IMAGE_BYTES + 1`. Le dépassement est détecté sans charger intentionnellement l'intégralité d'un fichier excessif; l'image fautive obtient un statut 413.
4. Les fichiers téléversés sont fermés dans un bloc `finally`.
5. `FaceEngine` décode les octets en image couleur BGR. Les contenus vides ou non décodables sont rejetés.
6. InsightFace détecte les visages. Zéro visage produit une erreur spécifique à l'image; plus d'un visage dans l'une ou l'autre image est rejeté.
7. L'embedding de chaque visage est converti en tableau `float32`.
8. Le service calcule le cosinus entre les embeddings, puis transforme la plage usuelle `[-1, 1]` vers `[0, 1]` avec `(cosinus + 1) / 2`. La valeur est bornée et le cas d'un vecteur de norme nulle renvoie 0.
9. La décision est `similarity >= FACE_SIMILARITY_THRESHOLD`. Le score retourné est arrondi à quatre décimales.
10. Les références aux octets sont remplacées par des valeurs vides dans le `finally` de la vérification. Aucun fichier ou embedding n'est écrit explicitement sur disque ou dans une base de données.

## 5. API HTTP

### `GET /health`

Indique que le processus HTTP répond. Réponse `200` :

```json
{
  "status": "ok",
  "service": "face-recognition"
}
```

Ce contrôle ne vérifie pas l'état du modèle InsightFace. En particulier, l'application journalise un échec de chargement du modèle au démarrage mais continue à démarrer; `/health` peut donc répondre `ok` tandis que `/face/verify` renvoie 503.

### `POST /face/verify`

Type de contenu : `multipart/form-data`.

| Champ | Obligatoire | Rôle |
|---|---:|---|
| `reference_image` | Oui | Image du visage de référence |
| `probe_image` | Oui | Image contenant le visage à vérifier |

Réponse `200` :

```json
{
  "verified": true,
  "similarity": 0.8421,
  "threshold": 0.3,
  "reference_face_detected": true,
  "probe_face_detected": true
}
```

Les valeurs numériques de cet exemple sont illustratives; le résultat dépend des images et du modèle. Les indicateurs de détection sont `true` dans une réponse de succès, puisqu'une détection unique dans chaque image est nécessaire pour arriver à la comparaison. Ils sont optionnels dans le schéma, principalement pour permettre `null`.

### Erreurs documentées par le code

Les erreurs utilisent normalement la forme suivante :

```json
{
  "status": "error",
  "code": "INVALID_IMAGE",
  "message": "..."
}
```

| HTTP | Code possible | Situation |
|---:|---|---|
| 400 | `INVALID_IMAGE` | Octets vides, format illisible, décodage ou détection en échec, embedding absent |
| 413 | `REFERENCE_IMAGE_TOO_LARGE` / `PROBE_IMAGE_TOO_LARGE` | Une image dépasse la limite configurée |
| 422 | `REFERENCE_FACE_NOT_FOUND` | Aucun visage dans l'image de référence |
| 422 | `PROBE_FACE_NOT_FOUND` | Aucun visage dans l'image de contrôle |
| 422 | `MULTIPLE_FACES_DETECTED` | Plus d'un visage dans une des images |
| 503 | `FACE_ENGINE_NOT_READY` | Le modèle n'est pas chargé |
| 500 | `VERIFICATION_INTERNAL_ERROR` | Erreur inattendue pendant la vérification |
| autre | `HTTP_ERROR` | Erreur HTTP non spécifique interceptée |

FastAPI peut aussi produire une erreur de validation 422 lorsque le formulaire ne contient pas les champs requis. Le gestionnaire global transforme les `HTTPException` en JSON cohérent, mais la validation standard de FastAPI n'est pas explicitement personnalisée dans ce code.

## 6. Configuration

Les valeurs par défaut et les variables d'environnement sont définies par Pydantic Settings. `Settings` lit le fichier `.env` avec encodage UTF-8, respecte la casse des noms et ignore les options supplémentaires.

| Variable | Défaut | Description |
|---|---:|---|
| `FACE_SIMILARITY_THRESHOLD` | `0.30` | Seuil inclusif de décision; vérifié si le score est supérieur ou égal |
| `HOST` | `0.0.0.0` | Adresse d'écoute, exposant le service sur les interfaces réseau |
| `PORT` | `8000` | Port prévu pour le serveur HTTP |
| `FACE_MAX_IMAGE_BYTES` | `8388608` (8 MiB) | Taille maximale de chaque fichier image |

`.env.example` documente ces valeurs, mais le code ne lance pas Uvicorn lui-même et le dépôt ne fournit pas de commande de démarrage. Le déploiement doit donc préciser le point d'entrée, par exemple `uvicorn app.main:app --host 0.0.0.0 --port 8000`, ou utiliser les valeurs `HOST` et `PORT` dans la commande d'orchestration.

## 7. Modèle et dépendances

`requirements.txt` déclare :

- **FastAPI** : endpoints HTTP et schémas OpenAPI.
- **Uvicorn** : serveur ASGI.
- **Pydantic 2** et **pydantic-settings** : validation et chargement de configuration.
- **python-multipart** : traitement des formulaires multipart.
- **InsightFace** : analyse faciale et extraction d'embeddings.
- **ONNX Runtime** : exécution du modèle sur CPU (`CPUExecutionProvider`).
- **NumPy** : traitement des embeddings et calcul numérique.
- **OpenCV headless** : décodage d'image sans dépendance à une interface graphique.

Le modèle `buffalo_l` et sa préparation avec une taille de détection `(640, 640)` sont codés dans `FaceEngine.load()`. Le chargement peut dépendre de la disponibilité des fichiers de modèle et de l'environnement. Il est effectué pendant le lifespan de FastAPI; l'échec est journalisé et n'empêche pas le processus de servir `/health`.

## 8. Journalisation et données

La journalisation est configurée au niveau INFO avec date/heure, niveau, logger et message. Le démarrage journalise le seuil et l'adresse/port configurés; la vérification journalise le résultat, le score et le seuil. Les erreurs inattendues incluent une trace via `logger.exception`.

La description FastAPI indique qu'aucune image ni aucun embedding n'est persisté. Le code ne les écrit effectivement pas sur disque. Toutefois, les octets, images décodées et embeddings existent temporairement en mémoire pendant le traitement; remplacer une variable d'octets par `b""` ne garantit pas l'effacement des copies mémoire internes ou des tableaux d'image. Les journaux peuvent révéler des scores et des résultats de vérification, mais pas le contenu image dans le chemin normal.

## 9. Déploiement et exploitation

Pour exécuter le service, l'environnement doit disposer d'une version Python compatible avec les dépendances, des bibliothèques requises et du modèle InsightFace accessible au processus. L'installation des dépendances se fait depuis `requirements.txt`; le service peut ensuite être lancé via Uvicorn en ciblant `app.main:app`.

Le service écoute par défaut sur toutes les interfaces réseau (`0.0.0.0`). Cette valeur facilite l'accès depuis un Raspberry Pi sur le LAN, mais l'accès doit être limité au réseau attendu par le pare-feu et l'infrastructure. Le dépôt ne contient aucun fichier de conteneur, script d'installation, manifeste de service ou configuration de proxy inverse.

FastAPI expose également la documentation OpenAPI à ses routes documentaires standard (notamment `/docs` et `/openapi.json`), sauf personnalisation externe au code.

## 10. Limites et points d'attention

1. **Seuil non validé ici** — `0.30` est une valeur de configuration commentée comme approximative dans `.env.example`; le dépôt ne contient pas de protocole de calibration ni de jeu de validation. La décision dépend fortement des données et des conditions de capture.
2. **Score transformé** — la valeur retournée est le cosinus transformé de `[-1, 1]` en `[0, 1]`, pas une probabilité calibrée que les personnes soient identiques.
3. **Visage unique obligatoire** — les photos de groupe et les images sans visage sont rejetées; il n'y a pas de sélection automatique du visage principal.
4. **Contrôles d'entrée limités** — la taille est plafonnée par fichier, mais le code ne définit pas explicitement de limite de dimensions en pixels, de délai, de quota de requêtes ou de concurrence.
5. **Pas d'authentification dans ce service** — toute entité pouvant joindre le port peut tenter une vérification; aucune clé API ni contrôle d'origine n'est défini.
6. **Pas de TLS configuré** — l'application ne configure pas HTTPS. Sur un réseau non fiable, un proxy ou une couche réseau sécurisée est nécessaire.
7. **Détails d'erreur interne** — le message de l'erreur 500 inclut la représentation de l'exception (`repr`), ce qui peut exposer des détails techniques au client.
8. **État de santé incomplet** — `/health` indique la disponibilité HTTP uniquement et ne reflète pas la disponibilité du modèle.
9. **Chargement CPU** — le fournisseur CPU est imposé; le temps de réponse et le débit dépendent du matériel, notamment sur Raspberry Pi.
10. **Effacement mémoire non garanti** — la remise à vide des variables d'octets est une réduction de durée de vie des références, pas une preuve d'effacement sécurisé de la mémoire.
11. **Absence de tests et d'intégration visibles** — aucun test, fichier README, client, pipeline CI ou code d'intégration n'est présent dans l'arborescence examinée.

## 11. Inventaire des fichiers

| Fichier | Responsabilité |
|---|---|
| `app/main.py` | Application FastAPI, cycle de vie, endpoints, taille des uploads, traduction des erreurs et journalisation |
| `app/face_engine.py` | Chargement InsightFace, décodage, détection, embeddings, score et décision |
| `app/config.py` | Paramètres d'environnement et singleton de configuration |
| `app/schemas.py` | Schémas Pydantic des réponses santé, succès et erreurs |
| `app/__init__.py` | Marque le répertoire `app` comme package Python |
| `requirements.txt` | Dépendances et plages de versions |
| `.env.example` | Exemple de configuration locale |
| `RAPPORT.md` | Présent rapport du projet |

## 12. Conclusion

Le dépôt met en œuvre une brique ciblée de vérification faciale pour un système plus large de boîte à médicaments. Son chemin nominal est simple et lisible : deux images entrantes, validation d'un visage unique par image, extraction de deux embeddings, calcul d'un score cosinus normalisé et comparaison à un seuil. Pour un déploiement réel, les décisions principales à traiter sont la calibration du seuil, la protection d'accès au service, la sécurisation du transport, la surveillance de la disponibilité du modèle et la validation sur les appareils et conditions de capture visés.
