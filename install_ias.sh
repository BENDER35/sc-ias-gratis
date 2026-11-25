#!/usr/bin/env bash
# install_ias.sh — Instalador interactivo de CLIs de IA con plan gratuito.
# Uso: ./install_ias.sh [--all] [--force] [--list] [--help]

set -uo pipefail

VERSION="1.0.0"

NOMBRES=(
  "opencode"
  "Claude Code"
  "Gemini CLI"
  "OpenAI Codex CLI"
  "GitHub Copilot CLI"
  "Qwen Code"
  "Ollama"
  "Aider"
)
BINARIOS=(
  "opencode"
  "claude"
  "gemini"
  "codex"
  "copilot"
  "qwen"
  "ollama"
  "aider"
)
DESCRIPCIONES=(
  "Open source; funciona con modelos locales o API, sin cuenta obligatoria"
  "CLI de Anthropic; acceso gratuito limitado segun cuenta"
  "CLI de Google; cuota gratuita con cuenta Google / Gemini API"
  "CLI de OpenAI; acceso gratuito limitado con cuenta ChatGPT"
  "CLI de GitHub Copilot; plan Copilot Free con cuota mensual"
  "CLI de Alibaba Qwen; cuota diaria gratuita con cuenta"
  "Modelos locales en tu maquina: 100% gratuito y sin cuenta"
  "Open source; trae tus propias claves (muchas con cuota gratuita)"
)
DOCS=(
  "https://opencode.ai/"
  "https://docs.anthropic.com/en/docs/claude-code"
  "https://github.com/google-gemini/gemini-cli"
  "https://developers.openai.com/codex/cli/"
  "https://docs.github.com/en/copilot"
  "https://github.com/QwenLM/qwen-code"
  "https://ollama.com/"
  "https://aider.chat/"
)
TOTAL=${#NOMBRES[@]}

C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
C_CYAN=$'\033[36m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'

FORCE=0
MODO="menu"

usage() {
  cat <<EOF
Instalador de CLIs de IA gratuitas v${VERSION}

Uso: $0 [opciones]

Opciones:
  --all     Instala todas sin mostrar el menu
  --force   Reinstala aunque el comando ya exista
  --list    Muestra el catalogo y sale
  -h, --help Muestra esta ayuda
EOF
}

while (($#)); do
  case "$1" in
    --all) MODO="all" ;;
    --force) FORCE=1 ;;
    --list) MODO="list" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opcion desconocida: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$MODO" == "list" ]]; then
  printf '%s\n' "Catálogo de CLIs gratuitas:"
  for ((i = 0; i < TOTAL; i++)); do
    printf '  %d) %-20s %-10s %s\n' "$((i + 1))" "${NOMBRES[i]}" "${BINARIOS[i]}" "${DESCRIPCIONES[i]}"
  done
  exit 0
fi

tiene_cmd() { command -v "$1" >/dev/null 2>&1; }

paso() {
  local mensaje="$1"; shift
  printf '  %s→%s %s\n' "$C_CYAN" "$C_OFF" "$mensaje"
  "$@"
}

fallo() { printf '  %s✗%s %s\n' "$C_RED" "$C_OFF" "$1" >&2; }

# npm global: usa el prefijo del usuario si no tenemos permisos de escritura
npm_global() {
  local paquete="$1" prefijo
  if ! tiene_cmd npm; then
    fallo "npm no está instalado; instala Node.js desde https://nodejs.org/"
    return 1
  fi
  prefijo="$(npm config get prefix 2>/dev/null || true)"
  if [[ -n "$prefijo" && -w "$prefijo" ]]; then
    npm install -g "$paquete"
  else
    mkdir -p "$HOME/.local"
    npm install -g --prefix "$HOME/.local" "$paquete"
    printf '%s  Nota: añade %s~/.local/bin%s al PATH.%s\n' \
      "$C_YELLOW" "$C_BOLD" "$C_OFF" "$C_OFF"
  fi
}

pipx_o_pip() {
  local paquete="$1"
  if tiene_cmd pipx; then
    pipx install "$paquete"
  elif tiene_cmd python3; then
    python3 -m pip install --user --upgrade "$paquete"
  else
    fallo "Se necesita pipx o python3 con pip"
    return 1
  fi
}

instalar() {
  case "$1" in
    0) # opencode: script oficial, con npm como respaldo
      if tiene_cmd curl; then
        paso "Instalando opencode con el script oficial" \
          bash -c 'curl -fsSL https://opencode.ai/install | bash'
      else
        npm_global opencode-ai
      fi
      ;;
    1) paso "Instalando Claude Code" npm_global @anthropic-ai/claude-code ;;
    2) paso "Instalando Gemini CLI" npm_global @google/gemini-cli ;;
    3) paso "Instalando OpenAI Codex CLI" npm_global @openai/codex ;;
    4) paso "Instalando GitHub Copilot CLI" npm_global @github/copilot ;;
    5) paso "Instalando Qwen Code" npm_global @qwen-code/qwen-code ;;
    6) # Ollama
      if [[ "$(uname -s)" == "Darwin" ]] && tiene_cmd brew; then
        paso "Instalando Ollama con Homebrew" brew install ollama
      elif tiene_cmd curl; then
        paso "Instalando Ollama con el script oficial" \
          bash -c 'curl -fsSL https://ollama.com/install.sh | sh'
      else
        fallo "Se necesita curl o Homebrew"
        return 1
      fi
      ;;
    7) paso "Instalando Aider" pipx_o_pip aider-chat ;;
  esac
}

# ---------- menú interactivo ----------
declare -a seleccion
for ((i = 0; i < TOTAL; i++)); do seleccion[i]=0; done
cursor=0
confirmado=0

dibujar_menu() {
  printf '\033[H\033[2J'
  printf '%s%sInstalador de IAs CLI gratuitas v%s%s\n\n' "$C_BOLD" "$C_CYAN" "$VERSION" "$C_OFF"
  printf '  %s↑↓%s mover  %sEspacio%s marcar  %sa%s todas  %sn%s ninguna  %sEnter%s instalar  %sq%s salir\n\n' \
    "$C_BOLD" "$C_OFF" "$C_BOLD" "$C_OFF" "$C_BOLD" "$C_OFF" \
    "$C_BOLD" "$C_OFF" "$C_BOLD" "$C_OFF" "$C_BOLD" "$C_OFF"
  for ((i = 0; i < TOTAL; i++)); do
    if ((i == cursor)); then marca="${C_CYAN}>${C_OFF}"; else marca="  "; fi
    if ((seleccion[i] == 1)); then check="${C_GREEN}[x]${C_OFF}"; else check="[ ]"; fi
    if tiene_cmd "${BINARIOS[i]}"; then estado="${C_DIM}(ya instalado)${C_OFF}"; else estado=""; fi
    printf '%s%s %s%-19s %s %s\n' "$marca" "$check" "$C_BOLD" "${NOMBRES[i]}" "$C_OFF" "$estado"
    printf '      %s%s%s\n' "$C_DIM" "${DESCRIPCIONES[i]}" "$C_OFF"
  done
  printf '\n  %sDocumentación: %shttps://github.com/BENDER35/sc-ias-gratis%s\n' \
    "$C_DIM" "$C_CYAN" "$C_OFF"
}

leer_tecla() {
  local tecla sec1 sec2
  IFS= read -rsn1 tecla || return 1
  if [[ "$tecla" == $'\033' ]]; then
    IFS= read -rsn1 -t 0.08 sec1 || true
    IFS= read -rsn1 -t 0.08 sec2 || true
    if [[ "$sec1" == "[" ]]; then
      case "$sec2" in
        A) cursor=$(((cursor + TOTAL - 1) % TOTAL)) ;;
        B) cursor=$(((cursor + 1) % TOTAL)) ;;
      esac
    fi
    return 0
  fi
  case "$tecla" in
    ' ') seleccion[cursor]=$((1 - seleccion[cursor])) ;;
    a|A) for ((i = 0; i < TOTAL; i++)); do seleccion[i]=1; done ;;
    n|N) for ((i = 0; i < TOTAL; i++)); do seleccion[i]=0; done ;;
    $'\n'|'') confirmado=1 ;;
    q|Q) printf '\nInstalación cancelada.\n'; exit 0 ;;
  esac
}

if [[ "$MODO" == "menu" ]]; then
  if [[ ! -t 0 ]]; then
    echo "El modo menú requiere una terminal interactiva; usa --all o --list." >&2
    exit 2
  fi
  printf '\033[?25l'
  trap 'printf "\033[?25h"' EXIT
  while ((confirmado == 0)); do
    dibujar_menu
    leer_tecla || { printf '\n'; break; }
  done
  printf '\033[?25h'
  trap - EXIT
  printf '\033[H\033[2J'
fi

# ---------- instalación ----------
declare -a resultado
hubo_error=0
instaladas=0

for ((i = 0; i < TOTAL; i++)); do
  if [[ "$MODO" == "all" ]] || ((seleccion[i] == 1)); then
    if tiene_cmd "${BINARIOS[i]}" && ((FORCE == 0)); then
      resultado[i]="OMITIDA"
      printf '\n%s%s%s ya está instalado: %s%s\n' \
        "$C_YELLOW" "${NOMBRES[i]}" "$C_OFF" "$(command -v "${BINARIOS[i]}")" "$C_OFF"
      continue
    fi
    printf '\n%s=== %s ===%s\n' "$C_BOLD" "${NOMBRES[i]}" "$C_OFF"
    if instalar "$i"; then
      resultado[i]="OK"
      instaladas=$((instaladas + 1))
    else
      resultado[i]="ERROR"
      hubo_error=1
    fi
  else
    resultado[i]="-"
  fi
done

printf '\n%s%sResumen%s\n' "$C_BOLD" "$C_CYAN" "$C_OFF"
printf '  %-20s %-10s %s\n' "HERRAMIENTA" "ESTADO" "RUTA / DOCUMENTACIÓN"
for ((i = 0; i < TOTAL; i++)); do
  if tiene_cmd "${BINARIOS[i]}"; then ruta="$(command -v "${BINARIOS[i]}")"; else ruta="${DOCS[i]}"; fi
  case "${resultado[i]}" in
    OK) color="$C_GREEN" ;;
    ERROR) color="$C_RED" ;;
    OMITIDA) color="$C_YELLOW" ;;
    *) color="$C_DIM" ;;
  esac
  printf '  %-20s %s%-10s%s %s\n' "${NOMBRES[i]}" "$color" "${resultado[i]}" "$C_OFF" "$ruta"
done

printf '\n%sInstaladas en esta ejecución: %d%s\n' "$C_BOLD" "$instaladas" "$C_OFF"
if ((hubo_error)); then
  printf '%sHubo errores; revisa el resumen.%s\n' "$C_RED" "$C_OFF"
  exit 1
fi
printf '%sTodo listo. Inicia sesión en cada CLI según su documentación.%s\n' "$C_GREEN" "$C_OFF"
exit 0
