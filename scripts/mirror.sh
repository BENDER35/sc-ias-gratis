#!/usr/bin/env bash
# mirror.sh — Empuja el HEAD actual a la otra plataforma de forma segura.
# Uso: scripts/mirror.sh <github|gitlab> <url-sin-token> [rama]
#
# Variables de entorno: GH_TOKEN (para github) o GITLAB_TOKEN (para gitlab).
# Las credenciales se insertan en la URL solo en memoria y toda la salida se
# redacta, de modo que el token nunca aparece en los logs de CI ni en remotos.

set -euo pipefail

PROVIDER="${1:?Uso: mirror.sh <github|gitlab> <url> [rama]}"
TARGET_URL="${2:?Falta la URL del repositorio destino}"
BRANCH="${3:-main}"

if [[ "$TARGET_URL" != https://* ]]; then
  echo "ERROR: la URL debe empezar por https://" >&2
  exit 2
fi

case "$PROVIDER" in
  github)
    : "${GH_TOKEN:?Se requiere GH_TOKEN}"
    CREDENCIALES="x-access-token:${GH_TOKEN}@"
    TOKEN="$GH_TOKEN"
    ;;
  gitlab)
    : "${GITLAB_TOKEN:?Se requiere GITLAB_TOKEN}"
    CREDENCIALES="oauth2:${GITLAB_TOKEN}@"
    TOKEN="$GITLAB_TOKEN"
    ;;
  *)
    echo "Proveedor desconocido: $PROVIDER (usa github o gitlab)" >&2
    exit 2
    ;;
esac

AUTH_URL="https://${CREDENCIALES}${TARGET_URL#https://}"
redactar() { sed "s/${TOKEN}/***/g"; }

export GIT_TERMINAL_PROMPT=0
REF="refs/remotes/mirror-target/${BRANCH}"
LOCAL_SHA="$(git rev-parse HEAD)"

# Leer el estado real del destino antes de escribir. Se traen todas las ramas
# (con comodín) para que un repositorio recién creado y vacío no sea un error.
if ! git fetch --quiet --no-tags --prune "$AUTH_URL" \
     "+refs/heads/*:refs/remotes/mirror-target/*" 2>&1 | redactar >&2; then
  echo "ERROR: no se pudo consultar ${TARGET_URL}" >&2
  exit 3
fi

if git rev-parse --verify -q "$REF" >/dev/null; then
  REMOTE_SHA="$(git rev-parse "$REF")"
else
  REMOTE_SHA=""
fi

# El destino ya tiene este commit: no hacemos nada. Esto corta el bucle
# GitHub -> GitLab -> GitHub -> ... cuando ambos lados están sincronizados.
if [[ "$REMOTE_SHA" == "$LOCAL_SHA" ]]; then
  echo "Sin cambios: ${BRANCH} ya está en ${LOCAL_SHA} en ${TARGET_URL}"
  exit 0
fi

# Si el destino tiene commits que aquí no existen, no los sobrescribimos.
# REMOTE debe ser ancestro de LOCAL para que el empuje sea fast-forward.
if [[ -n "$REMOTE_SHA" ]] && ! git merge-base --is-ancestor "$REMOTE_SHA" "$LOCAL_SHA"; then
  echo "ERROR: el destino tiene historial divergente (${REMOTE_SHA})." >&2
  echo "Abortando para no perder commits. Resuélvelo manualmente con un rebase." >&2
  exit 4
fi

LEASE="refs/heads/${BRANCH}:${REMOTE_SHA}"

if git push --quiet --force-with-lease="$LEASE" "$AUTH_URL" \
     "HEAD:refs/heads/${BRANCH}" 2>&1 | redactar >&2; then
  echo "OK: ${LOCAL_SHA} espejado en ${TARGET_URL} (${BRANCH})"
else
  echo "ERROR: falló el push a ${TARGET_URL}" >&2
  exit 5
fi
