# ag Search — Omarchy bar plugin

Search your files with [ag (The Silver Searcher)](https://github.com/ggreer/the_silver_searcher)
directly from the Omarchy bar. Click the 🔍 icon, type a query, press Enter —
matches appear with their full path and line number, and Enter (or click)
opens the selected match in your editor at the right line.

## Install

Requires `ag` (package `the_silver_searcher`) and `omarchy-launch-editor`
(ships with Omarchy).

```sh
omarchy plugin add <this-repo-url> --enable
```

Place it in a bar section if needed:

```sh
omarchy bar move ag_search --section right
```

## Usage

- Type a query and press **Enter** to search.
- **Up/Down** (or hover) move through the results.
- **Enter** or **click** opens the selected match in your default editor.
- **Esc** clears the query; **Esc** again closes the popup.

## Configuration

Settings live inline on the plugin's entry in `~/.config/omarchy/shell.json`:

| Setting | Default | Meaning |
|---------|---------|---------|
| `folder` | `~` | Search root. `~` or `~/something` expand to your home directory; any other path is used as-is. |
| `prompt` | `🔍 ` | Prompt shown in the popup. |

Example entry:

```json
{ "id": "ag_search", "folder": "~/Documents", "prompt": "search: " }
```

## Notes

- Results are capped at 50; searches time out after 8 seconds.
- Opening a match runs `bin/ag-open`, which reads your default editor from
  `~/.local/state/omarchy/defaults/editor` and passes the correct
  `file:line` syntax for nvim/vim, helix, nano, micro, and VS Code.
- Saving files under `~/.config/omarchy/plugins/ag_search/` hot-reloads the
  plugin in the running shell — no restart needed.

## License

MIT — see [LICENSE](LICENSE).
