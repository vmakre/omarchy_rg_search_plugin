# rg Search — Omarchy bar plugin

Search your files with [ripgrep](https://github.com/BurntSushi/ripgrep)
directly from the Omarchy bar. Click the 🔍 icon, type a query, press Enter —
matches appear with their full path and line number, and Enter (or click)
opens the selected match in your editor at the right line.

## Install

Requires `rg` (package `ripgrep`) and `omarchy-launch-editor`
(ships with Omarchy).

```sh
omarchy plugin add https://github.com/vmakre/omarchy_rg_search_plugin --enable
```

Place it in a bar section if needed:

```sh
omarchy bar move rg_search.plugin --section right
```

Remove plugin

```sh
omarchy plugin remove rg_search.plugin
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
{ "id": "rg_search", "folder": "~/Documents", "prompt": "search: " }
```

## Notes

- Results are capped at 50; searches time out after 8 seconds.
- Search is smart-case, like ag was: an all-lowercase query also matches
  uppercase text, while any uppercase character makes the search case-sensitive.
- Opening a match runs `bin/rg-open`, which reads your default editor from
  `~/.local/state/omarchy/defaults/editor` and passes the correct
  `file:line` syntax for nvim/vim, helix, nano, micro, and VS Code.
- Saving files under `~/.config/omarchy/plugins/rg_search/` hot-reloads the
  plugin in the running shell — no restart needed.


## License

MIT — see [LICENSE](LICENSE).
