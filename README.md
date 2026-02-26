# ralph-setup

Scaffold [Ralph TUI](https://github.com/ralphcodeai/ralph-tui) and [Kiro CLI](https://cli.kiro.dev) with locked-down security configs in any project.

Both tools let you run AI coding agents locally. `ralph-setup` drops opinionated, security-first config files into your project so agents can only do what you explicitly allow — no web access, no secret exfiltration, no surprise `git push`.

## Install

```bash
npm install -g ralph-setup
```

## Usage

```bash
ralph-setup init [path]           # Scaffold both Ralph TUI + Kiro (default)
ralph-setup init --ralph [path]   # Ralph TUI only
ralph-setup init --kiro [path]    # Kiro CLI only
```

Flags can be combined: `--ralph --kiro` is the same as no flags (both).

### Examples

```bash
ralph-setup init                  # Set up both in current directory
ralph-setup init ./my-app         # Set up both in ./my-app
ralph-setup init --kiro ./my-app  # Set up Kiro only in ./my-app
```

## What gets created

### Ralph TUI (`--ralph`)

| File | Purpose |
|------|---------|
| `.ralph-tui/config.toml` | Ralph TUI config — sandbox, env filtering, agent settings |
| `.claude/settings.json` | Claude Code permissions — explicit allow/deny lists |
| `prd.json` | User story tracker template for iterative development |

### Kiro CLI (`--kiro`)

| File | Purpose |
|------|---------|
| `.kiro/settings/mcp.json` | MCP server config (empty by default) |
| `.kiro/steering/project.md` | Project context and conventions for Kiro |
| `.kiro/agents/dev.json` | Locked-down dev agent with restricted tool access |

## Security defaults

Both configs follow the same principles:

- **No web access** — `WebFetch` and `WebSearch` are blocked
- **No secret exfiltration** — env vars matching `*_TOKEN`, `*_PASSWORD`, `AWS_*`, etc. are filtered out
- **No network escape** — `curl`, `wget`, `ssh`, `scp` are denied in bash
- **No destructive git** — `git push`, `git remote` are blocked
- **Explicit allowlists** — only approved commands (`npm run`, `git diff`, `ls`, etc.) are permitted

## Re-running is safe

Running `ralph-setup init` again in the same directory will skip any files that already exist, so your customizations are never overwritten.

## License

MIT
