# =============================================================================
# Dockerfile — Site statique servi par Nginx (Alpine).
#
# Principes appliqués :
#   - image de base minimale et figée (nginx:alpine) ;
#   - copie du contenu statique dans la racine web de Nginx ;
#   - configuration durcie (en-têtes de sécurité, gzip, cache) ;
#   - exécution la moins privilégiée possible (utilisateur non root) ;
#   - HEALTHCHECK intégré pour la supervision du conteneur.
# =============================================================================

# Version figée pour une construction reproductible.
FROM nginx:1.27-alpine

# Métadonnées de l'image (norme OCI).
LABEL org.opencontainers.image.title="docker-static-site" \
      org.opencontainers.image.description="Site statique HTML/CSS/JS empaqueté dans Nginx pour la portabilité." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="Noumabeu Moutacdie Jordan"

# Remplacement de la configuration par défaut par la nôtre (gzip, cache,
# en-têtes de sécurité, écoute sur le port 8080 non privilégié).
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Copie du site statique dans la racine web de Nginx.
COPY site/ /usr/share/nginx/html/

# --- Exécution avec le moindre privilège ------------------------------------
# L'image officielle nginx fournit déjà l'utilisateur et le groupe « nginx ».
# On ajuste les permissions des répertoires nécessaires puis on bascule sur
# cet utilisateur non root. Aucun port < 1024 n'est utilisé, ce qui rend
# l'élévation de privilèges inutile.
RUN mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp \
             /tmp/uwsgi_temp /tmp/scgi_temp \
    && chown -R nginx:nginx /usr/share/nginx/html /tmp/client_temp \
             /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp \
    && chmod -R u+rwX,go+rX /usr/share/nginx/html

USER nginx

# Port applicatif non privilégié exposé par le conteneur.
EXPOSE 8080

# --- Supervision de l'état --------------------------------------------------
# Interroge le point d'entrée /healthz défini dans nginx.conf.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1

# Lancement de Nginx au premier plan (PID 1 maître).
CMD ["nginx", "-g", "daemon off;"]
