# PAC (Project-Ability-Codex)

A Roblox experience built around a data-driven combat framework: specs, subspecs, skills, hooks and reactive replication.

## Start here

- Developers: [Obsidian vault — Home](obsidian/Home.md), then the [Developer map](obsidian/01-Maps/Developer%20map.md).
- Agents and automation: [AGENTS.md](AGENTS.md) — short rules plus a route to the relevant vault notes.
- Русская версия: [Главная (RU)](<obsidian/i18n/ru/Home (RU).md>) и [карта разработчика (RU)](<obsidian/i18n/ru/Developer map (RU).md>).

## Build

```bash
rojo build -o PAC.rbxlx
rojo serve
```

Open `PAC.rbxlx` in Roblox Studio with the Rojo server running.

## Verify

```bash
lune run tools/format.luau --fix --src
```

There is no automated verification suite in the current tooling; verify behaviour by playtesting in Studio. See `obsidian/04-How-to/Formatting and inspection.md`.

## License

See [LICENSE](LICENSE).
