# =============================================================================
# Makefile, Cycle de vie du site statique conteneurisé.
#
# Cibles principales :
#   make build         Construit l'image Docker locale
#   make run           Démarre le conteneur (http://localhost:8088)
#   make stop          Arrête et supprime le conteneur
#   make logs          Affiche les logs du conteneur (suivi en direct)
#   make publish-ghcr  Construit et publie l'image sur GHCR
#   make help          Affiche cette aide
#
# Variables surchargeables :
#   IMAGE_NAME   Nom de l'image           (def. docker-static-site)
#   IMAGE_TAG    Tag de l'image           (def. latest)
#   HOST_PORT    Port exposé sur l'hôte   (def. 8088)
#   GHCR_OWNER   Compte/organisation GHCR (def. valeur du dépôt distant)
#
# Exemple :
#   make publish-ghcr GHCR_OWNER=mon-compte IMAGE_TAG=v1.0.0
# =============================================================================

# Utilise bash avec un mode strict pour chaque recette.
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# --- Variables configurables -------------------------------------------------
IMAGE_NAME    ?= docker-static-site
IMAGE_TAG     ?= latest
CONTAINER_NAME?= docker-static-site
HOST_PORT     ?= 8088
CONTAINER_PORT?= 8080
GHCR_REGISTRY ?= ghcr.io
GHCR_OWNER    ?=

LOCAL_IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)

.DEFAULT_GOAL := help

# Toutes les cibles sont « phony » (aucune ne produit de fichier homonyme).
.PHONY: help build run stop restart logs shell publish-ghcr clean

# --- Aide --------------------------------------------------------------------
help: ## Affiche la liste des cibles disponibles
	@echo "Cibles disponibles :"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# --- Construction ------------------------------------------------------------
build: ## Construit l'image Docker locale
	docker build --tag "$(LOCAL_IMAGE)" .

# --- Exécution ---------------------------------------------------------------
run: build ## Démarre le conteneur en arrière-plan (http://localhost:$(HOST_PORT))
	docker run --detach \
		--name "$(CONTAINER_NAME)" \
		--publish "$(HOST_PORT):$(CONTAINER_PORT)" \
		--restart unless-stopped \
		"$(LOCAL_IMAGE)"
	@echo "Site disponible sur http://localhost:$(HOST_PORT)"

# --- Arrêt -------------------------------------------------------------------
stop: ## Arrête et supprime le conteneur s'il existe
	@docker rm --force "$(CONTAINER_NAME)" >/dev/null 2>&1 \
		&& echo "Conteneur $(CONTAINER_NAME) arrêté et supprimé." \
		|| echo "Aucun conteneur $(CONTAINER_NAME) en cours d'exécution."

# --- Redémarrage -------------------------------------------------------------
restart: stop run ## Redémarre le conteneur

# --- Logs --------------------------------------------------------------------
logs: ## Affiche et suit les logs du conteneur
	docker logs --follow "$(CONTAINER_NAME)"

# --- Shell de diagnostic -----------------------------------------------------
shell: ## Ouvre un shell dans le conteneur en cours d'exécution
	docker exec -it "$(CONTAINER_NAME)" /bin/sh

# --- Publication GHCR --------------------------------------------------------
publish-ghcr: ## Construit et publie l'image sur GHCR (requiert GHCR_OWNER)
	@if [ -z "$(GHCR_OWNER)" ]; then \
		echo "Erreur : définissez GHCR_OWNER, ex. make publish-ghcr GHCR_OWNER=mon-compte" >&2; \
		exit 1; \
	fi
	$(eval REMOTE_IMAGE := $(GHCR_REGISTRY)/$(shell echo '$(GHCR_OWNER)' | tr '[:upper:]' '[:lower:]')/$(IMAGE_NAME):$(IMAGE_TAG))
	docker build --tag "$(REMOTE_IMAGE)" .
	docker push "$(REMOTE_IMAGE)"
	@echo "Image publiée : $(REMOTE_IMAGE)"

# --- Nettoyage ---------------------------------------------------------------
clean: stop ## Supprime le conteneur et l'image locale
	@docker image rm "$(LOCAL_IMAGE)" >/dev/null 2>&1 \
		&& echo "Image $(LOCAL_IMAGE) supprimée." \
		|| echo "Aucune image $(LOCAL_IMAGE) à supprimer."
