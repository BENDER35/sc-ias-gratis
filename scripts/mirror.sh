#!/usr/bin/env bash
# mirror.sh — Empuja el HEAD actual a la otra plataforma de forma segura.
# Uso: scripts/mirror.sh <github|gitlab> <url-sin-token> [rama]
#
# Variables de entorno: GH_TOKEN (para github) o GITLAB_TOKEN (para gitlab).
# El token se envía como cabecera HTTP, nunca dentro de la URL, para que no
# aparezca en los logs de CI ni en `git remote -v`.

set -euo pipefail

PROVIDER="${1:?Uso: mirror.sh <github|gitlab> <url> [rama]}"
TARGET_URL="${2:?Falta la URL del repositorio destino}"
BRANCH="${3:-main}"

case "$PROVIDER" in
  github)
    : "${GH_TOKEN:?Se requiere GH_TOKEN}"
    AUTH_HEADER="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')"
    AUTH_BASE="https://github.com/"
    ;;
  gitlab)
    : "${GITLAB_TOKEN:?Se requiere GITLAB_TOKEN}"
    AUTH_HEADER="PRIVATE-TOKEN: ${GITLAB_TOKEN}"
    AUTH_BASE="https://gitlab.com/"
    ;;
  *)
    echo "Proveedor desconocido: $PROVIDER (usa github o gitlab)" >&2
    exit 2
    ;;
esac

export GIT_TERMINAL_PROMPT=0
REF="refs/remotes/mirror-target/${BRANCH}"
LOCAL_SHA="$(git rev-parse HEAD)"

# Leer el estado real del destino antes de escribir. Se traen todas las ramas
# (con comodín) para que un repositorio recién creado y vacío no sea un error.
if ! git -c "http.${AUTH_BASE}.extraheader=${AUTH_HEADER}" fetch --quiet --no-tags \
     "$TARGET_URL" "+refs/heads/*:refs/remotes/mirror-target/*"; then
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
if [[ -n "$REMOTE_SHA" ]] && ! git merge-base --is-ancestor "$LOCAL_SHA" "$REMOTE_SHA"; then
  echo "ERROR: el destino tiene historial divergente (${REMOTE_SHA})." >&2
  echo "Abortando para no perder commits. Resuélvelo manualmente con un rebase." >&2
  exit 4
fi

LEASE="refs/heads/${BRANCH}:${REMOTE_SHA}"

if git -c "http.${AUTH_BASE}.extraheader=${AUTH_HEADER}" push --quiet \
     --force-with-lease="$LEASE" "$TARGET_URL" "HEAD:refs/heads/${BRANCH}"; then
  echo "OK: ${LOCAL_SHA} espejado en ${TARGET_URL} (${BRANCH})"
else
  echo "ERROR: falló el push a ${TARGET_URL}" >&2
  exit 5
fi
