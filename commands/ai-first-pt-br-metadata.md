Apply the optional pt_BR command metadata overlay to the global OpenCode config.

Run from the ai-first-kit checkout:

```bash
bash scripts/apply-pt-br-metadata-command.sh ~/.config/opencode/opencode.jsonc
```

Then restart OpenCode. The command adds these plugins to `opencode.jsonc` if missing:

```json
"./plugins/pt-br-metadata.js",
"./plugins/plugin-display-names.js"
```

Do not edit command descriptions directly for this overlay. Keep the translation patch centralized in `plugins/pt-br-metadata.js` and apply it through this command so it can be reproduced on other machines.
