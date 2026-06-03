# Docker Static Site

> Empaqueter un site statique HTML / CSS / JS dans un conteneur Docker pour
> garantir sa **portabilité**, puis le **déployer** de façon reproductible.

Cette démo sert une petite landing page **sobre, responsive et sans framework**
à l'aide de **Nginx** dans une image **Docker** légère. Le même artefact tourne
à l'identique sur votre poste, en intégration continue et en production —
fini le « ça marche sur ma machine ».

---

## Objectif

L'idée est volontairement simple, mais le packaging est de qualité production :

- un site statique (`site/`) écrit en HTML/CSS/JS pur, sans dépendance ni
  outil de build côté front ;
- une image Docker basée sur `nginx:alpine`, **durcie** (en-têtes de sécurité,
  `HEALTHCHECK`, exécution **non root**, port non privilégié) ;
- une orchestration locale en une commande via **Docker Compose** ;
- un **Makefile** pour le cycle de vie courant (build, run, stop, logs) ;
- un pipeline **GitHub Actions** qui construit et publie l'image sur le
  **GitHub Container Registry (GHCR)** à chaque push sur `main`.

---

## Prérequis

| Outil           | Version conseillée | Remarque                                      |
| --------------- | ------------------ | --------------------------------------------- |
| Docker Engine   | 24+                | Inclut `docker build` et `docker run`.        |
| Docker Compose  | v2 (`docker compose`) | Intégré aux versions récentes de Docker.   |
| GNU Make        | 3.81+              | Optionnel, pour les raccourcis du `Makefile`. |
| Un navigateur   | —                  | Pour ouvrir <http://localhost:8088>.          |

Aucun environnement Node.js n'est requis : le site ne dépend d'**aucun**
paquet npm.

---

## Arborescence

```text
docker-static-site/
├── site/                      # Contenu statique servi par Nginx
│   ├── index.html             # Landing page sémantique et accessible
│   ├── styles.css             # Styles (variables CSS, grid, thème clair/sombre)
│   └── app.js                 # JS natif : menu mobile, bouton « copier », année
├── Dockerfile                 # Image nginx:alpine durcie (non root, HEALTHCHECK)
├── nginx.conf                 # gzip, cache, en-têtes de sécurité, /healthz
├── docker-compose.yml         # Service web, port 8088:8080
├── .dockerignore              # Contexte de build minimal
├── Makefile                   # build / run / stop / logs / publish-ghcr
├── .github/workflows/docker.yml  # CI : build + publication GHCR
├── .gitignore
├── LICENSE                    # MIT — Noumabeu Moutacdie Jordan, 2026
└── README.md
```

> **À propos des ports.** Pour pouvoir s'exécuter en utilisateur **non root**,
> Nginx écoute à l'intérieur du conteneur sur le port **8080** (non privilégié,
> ≥ 1024) au lieu du port 80. Côté hôte, on expose ce service sur le port
> **8088**. La projection est donc `8088:8080`.

---

## Démarrage rapide

### Option A — Docker (build & run)

```bash
# 1. Construire l'image
docker build -t docker-static-site .

# 2. Lancer le conteneur (Ctrl+C pour arrêter, le conteneur est supprimé)
docker run --rm -p 8088:8080 docker-static-site
```

Ouvrez ensuite **<http://localhost:8088>**.

### Option B — Docker Compose

```bash
# Construit l'image si besoin puis démarre le service
docker compose up --build

# …ou en arrière-plan
docker compose up -d

# Arrêt et nettoyage
docker compose down
```

Le service est exposé sur **<http://localhost:8088>**.

### Option C — Makefile

```bash
make build     # Construit l'image locale
make run       # Démarre le conteneur en arrière-plan (http://localhost:8088)
make logs      # Suit les logs du conteneur
make stop      # Arrête et supprime le conteneur
make help      # Liste toutes les cibles disponibles
```

Les variables sont surchargeables, par exemple pour changer le port hôte :

```bash
make run HOST_PORT=9090   # le site sera alors sur http://localhost:9090
```

---

## Vérifier le bon fonctionnement

```bash
# Page d'accueil (doit renvoyer 200)
curl -I http://localhost:8088/

# Point de contrôle de santé utilisé par le HEALTHCHECK Docker
curl http://localhost:8088/healthz      # -> ok

# État de santé du conteneur (colonne STATUS : "healthy")
docker ps
```

Vous pouvez aussi inspecter les en-têtes de sécurité renvoyés par Nginx :

```bash
curl -sI http://localhost:8088/ | grep -iE \
  'content-security-policy|x-content-type-options|referrer-policy|permissions-policy'
```

---

## Publication sur GHCR

### Automatique (recommandé)

À chaque **push sur `main`** (ou tag `vX.Y.Z`), le workflow
`.github/workflows/docker.yml` :

1. construit l'image avec Docker Buildx (avec cache GitHub Actions) ;
2. s'authentifie sur `ghcr.io` à l'aide du `GITHUB_TOKEN` fourni
   automatiquement (permission `packages: write`) ;
3. publie l'image taguée sous
   `ghcr.io/<owner>/<repo>` (tags `latest`, `sha-…`, version sémantique sur tag).

Les **pull requests** déclenchent une construction de **validation** sans
publication.

> Après la première publication, pensez à rendre le package **public** (ou à
> gérer ses accès) depuis l'onglet *Packages* du dépôt GitHub si vous souhaitez
> le récupérer sans authentification.

Récupérer puis exécuter l'image publiée :

```bash
docker pull ghcr.io/<owner>/<repo>:latest
docker run --rm -p 8088:8080 ghcr.io/<owner>/<repo>:latest
```

### Manuelle (depuis votre poste)

```bash
# Connexion à GHCR avec un Personal Access Token (scope: write:packages)
echo "$GHCR_TOKEN" | docker login ghcr.io -u <owner> --password-stdin

# Construction + publication via le Makefile
make publish-ghcr GHCR_OWNER=<owner> IMAGE_TAG=v1.0.0
```

---

## Sécurité et durcissement

Le conteneur applique plusieurs bonnes pratiques :

- **Image minimale** : `nginx:alpine` (version figée pour la reproductibilité).
- **Exécution non root** : Nginx tourne sous l'utilisateur `nginx`, sur un
  port non privilégié.
- **En-têtes de sécurité** (`nginx.conf`) : `Content-Security-Policy`,
  `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`,
  `Permissions-Policy`, `Cross-Origin-Opener-Policy`,
  `Cross-Origin-Resource-Policy`.
- **`server_tokens off`** : la version de Nginx n'est pas divulguée.
- **`HEALTHCHECK`** : auto-supervision via l'endpoint `/healthz`.
- **Durcissement Compose** : `read_only`, `cap_drop: ALL`,
  `no-new-privileges`, systèmes de fichiers temporaires en `tmpfs`.

---

## Ce que ça démontre

- **Portabilité** : un artefact unique et immuable, identique du poste de
  développement à la production.
- **Conteneurisation propre** d'un site statique : Nginx + configuration
  durcie plutôt qu'un serveur de développement.
- **Bonnes pratiques de sécurité** des conteneurs : moindre privilège,
  en-têtes HTTP, surface d'attaque réduite.
- **Industrialisation** : orchestration (Compose), automatisation (Makefile)
  et **CI/CD** (GitHub Actions → GHCR).
- **Front sobre et accessible** : HTML sémantique, responsive, thème
  clair/sombre, le tout **sans aucune dépendance JavaScript**.

---

## Dépannage

| Symptôme                                   | Piste de résolution                                              |
| ------------------------------------------ | --------------------------------------------------------------- |
| `port is already allocated`                | Le port 8088 est occupé : `make run HOST_PORT=9090` ou libérez-le. |
| Le conteneur reste `unhealthy`             | Vérifiez les logs : `make logs` ; testez `curl …/healthz`.       |
| `permission denied` au build               | Assurez-vous que le démon Docker est démarré et accessible.      |
| L'image GHCR n'est pas téléchargeable      | Rendez le package public ou authentifiez-vous (`docker login`). |

---

## Licence

Distribué sous licence **MIT**. Voir le fichier [`LICENSE`](./LICENSE).

© 2026 **Noumabeu Moutacdie Jordan**.
