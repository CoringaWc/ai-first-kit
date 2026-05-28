import path from "node:path";
import { fileURLToPath } from "node:url";

function stripExtension(name) {
  return name.replace(/\.(cjs|mjs|js|ts)$/i, "");
}

function shortPluginName(value) {
  if (typeof value !== "string") return value;

  if (value.startsWith("file://")) {
    return stripExtension(path.basename(fileURLToPath(value)));
  }

  if (value.startsWith("./") || value.startsWith("../") || value.startsWith("/") || value.startsWith("~/")) {
    return stripExtension(path.basename(value));
  }

  return value;
}

export function formatPluginEntry(entry) {
  if (Array.isArray(entry)) return [shortPluginName(entry[0]), entry[1]];
  return shortPluginName(entry);
}

export const PluginDisplayNamesPlugin = async () => ({
  config: (config) => {
    if (!Array.isArray(config.plugin)) return;
    config.plugin = config.plugin.map(formatPluginEntry);
  },
});

export default PluginDisplayNamesPlugin;
