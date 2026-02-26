# ralph-setup

Scaffold [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Kiro CLI](https://cli.kiro.dev) configs for [Ralph TUI](https://github.com/ralphcodeai/ralph-tui) in any project.

Ralph TUI can orchestrate both Claude Code and Kiro CLI as agent backends. `ralph-setup` drops opinionated, security-first config files into your project so agents can only do what you explicitly allow — no web access, no secret exfiltration, no surprise `git push`.

## Why not just use Ralph TUI directly?

Ralph TUI is the orchestration engine — it runs iterations, tracks user stories, and manages the agent loop. But it ships with no opinion about security. You install it and it works, but the agent has full access to everything by default.

`ralph-setup` adds the security-first config layer on top:

- **Locked-down permissions** — explicit allow/deny lists so agents can only run approved commands (`npm run`, `git diff`, `ls`, etc.) and are blocked from `git push`, `curl`, `ssh`, reading `~/.ssh`, `.env`, etc.
- **Sandbox + env filtering** — OS-level sandboxing enabled, and env vars matching `*_TOKEN`, `*_PASSWORD`, `AWS_*` are filtered out so credentials never leak to the agent process
- **Web access blocked** — `WebFetch` and `WebSearch` are denied in both Claude Code and Kiro configs, so agents can't phone home or exfiltrate data
- **Kiro parity** — same locked-down posture for Kiro CLI via `.kiro/agents/dev.json` with restricted tool allowlists
- **One command** — instead of manually creating 3-6 config files and knowing which permissions to set, `ralph-setup init` gives you a secure starting point in seconds

Ralph TUI is the engine, `ralph-setup` is the guardrails.

## Install

```bash
npm install -g ralph-setup
```

## Usage

```bash
ralph-setup init [path]            # Scaffold both Claude Code + Kiro (default)
ralph-setup init --claude [path]   # Claude Code only
ralph-setup init --kiro [path]     # Kiro CLI only
```

Flags can be combined: `--claude --kiro` is the same as no flags (both).

### Examples

```bash
ralph-setup init                  # Set up both in current directory
ralph-setup init ./my-app         # Set up both in ./my-app
ralph-setup init --kiro ./my-app  # Set up Kiro only in ./my-app
```

## What gets created

### Claude Code (`--claude`)

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
