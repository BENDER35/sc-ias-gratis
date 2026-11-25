# sc-ias-gratis

Instalador por terminal de CLIs de IA con **plan gratuito**, con menú interactivo, espejo automático **GitHub ⇄ GitLab**, verificación y release en ZIP.

- GitHub: <https://github.com/BENDER35/sc-ias-gratis>
- GitLab: <https://gitlab.com/BENDER_5000/sc-ias-gratis>

> Las condiciones de los planes gratuitos cambian con el tiempo. El instalador no guarda claves ni tokens: cada CLI te pedirá iniciar sesión por su propio mecanismo. Consulta siempre la documentación oficial enlazada más abajo antes de usar una herramienta en producción.

## Herramientas incluidas

| # | Herramienta | Comando | Modalidad gratuita | Instalación |
|---|---|---|---|---|
| 1 | [opencode](https://opencode.ai/) | `opencode` | Código abierto; permite modelos locales (Ollama) sin cuenta | Script oficial (`curl`), fallback npm |
| 2 | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `claude` | Acceso gratuito limitado según cuenta Anthropic | npm |
| 3 | [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `gemini` | Cuota gratuita con cuenta Google / Gemini API | npm |
| 4 | [OpenAI Codex CLI](https://developers.openai.com/codex/cli/) | `codex` | Acceso gratuito limitado con cuenta ChatGPT | npm |
| 5 | [GitHub Copilot CLI](https://docs.github.com/en/copilot) | `copilot` | Plan Copilot Free con cuota mensual | npm |
| 6 | [Qwen Code](https://github.com/QwenLM/qwen-code) | `qwen` | Cuota diaria gratuita con cuenta Alibaba Cloud | npm |
| 7 | [Ollama](https://ollama.com/) | `ollama` | 100 % local y gratuito, sin cuenta | Script oficial / Homebrew |
| 8 | [Aider](https://aider.chat/) | `aider` | Código abierto; usa claves propias (muchas con cuota gratuita) | `pipx` / `pip --user` |

## Instalación

```bash
git clone https://github.com/BENDER35/sc-ias-gratis.git
cd sc-ias-gratis
chmod +x install_ias.sh scripts/*.sh
./install_ias.sh
```

Menú interactivo:

- `↑` / `↓` mover el cursor
- `Espacio` marcar/desmarcar
- `a` seleccionar todas, `n` no seleccionar ninguna
- `Enter` instalar las seleccionadas, `q` salir

Modo no interactivo:

```bash
./install_ias.sh --list     # lista las herramientas y sus comandos
./install_ias.sh --all      # instala todas
./install_ias.sh --all --force  # reinstala aunque ya estén presentes
```

Al terminar se muestra un resumen con `OK`, `OMITIDA` o `ERROR` para cada herramienta y la ruta del ejecutable. Si npm/pipx instalan en `~/.local`, añade `export PATH="$HOME/.local/bin:$PATH"` a tu shell.

## Espejo automático bidireccional

Cada push a `main` se replica en la otra plataforma:

- **GitHub Actions** (`.github/workflows/mirror.yml`) empuja a GitLab con `GITLAB_TOKEN`.
- **GitLab CI** (`.gitlab-ci.yml`) empuja a GitHub con `GH_TOKEN`.

Ambos usan `scripts/mirror.sh`, que:

1. Consulta la rama de destino antes de escribir.
2. Si el SHA ya coincide, no hace nada (esto **evita el bucle infinito** entre plataformas).
3. Si el destino contiene commits que no están en el origen, aborta para no perder historial.
4. Empuja con `--force-with-lease` para proteger cambios concurrentes.

Los tokens se guardan como secretos enmascarados (`GITLAB_TOKEN` en GitHub, `GH_TOKEN` en GitLab). `mirror.sh` los inyecta en la URL solo en memoria y redacta cualquier salida, por lo que no quedan en los logs ni en `git remote -v`.

### Reconfiguración manual

```bash
gh secret set GITLAB_TOKEN --repo BENDER35/sc-ias-gratis
glab api --method POST /projects/89453204/variables \
  -f key=GH_TOKEN -f value="$(gh auth token)" -f masked=true -f protected=true
```

Sincronización manual desde un clon local con ambos remotos:

```bash
./scripts/mirror.sh github https://github.com/BENDER35/sc-ias-gratis.git main
./scripts/mirror.sh gitlab https://gitlab.com/BENDER_5000/sc-ias-gratis.git main
```

## Verificación

```bash
./scripts/verify.sh          # comprobaciones locales + remotas
./scripts/verify.sh --local  # solo comprobaciones locales
```

Comprueba sintaxis de los scripts, presencia de archivos, remotos accesibles, igualdad de SHA en `main`, existencia de los secretos de CI y del release.

## Release

```bash
./scripts/release.sh v1.0.0
```

Genera `sc-ias-gratis-v1.0.0.zip` (sin `.git`), crea el tag y la release en GitHub con el ZIP como asset, y publica la release en GitLab enlazando el mismo asset y el archivo del repositorio.

## Estructura

```
.
├── install_ias.sh              # menú interactivo
├── scripts/
│   ├── mirror.sh               # espejo seguro GitHub ⇄ GitLab
│   ├── verify.sh               # verificación
│   └── release.sh              # ZIP + release en ambas plataformas
├── .github/workflows/mirror.yml
├── .gitlab-ci.yml
└── README.md
```

Licencia: MIT.

El espejo se verifica en ambas direcciones: un push en GitHub se replica en GitLab
mediante GitHub Actions, y un push en GitLab se replica en GitHub mediante GitLab CI.
El script `mirror.sh` compara SHA antes de empujar, por lo que un commit ya
sincronizado no genera nuevos pipelines.
