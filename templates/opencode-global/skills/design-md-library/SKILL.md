---
name: design-md-library
description: "Global: Biblioteca de referências design.md de marcas e produtos. Use ao projetar, redesenhar, tematizar ou estilizar uma UI no estilo de uma marca conhecida, ou quando precisar de tokens curados de tipografia, cor, espaçamento e movimento."
---

# design-md-library

Wrapper around the local clone of [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md).

## When to invoke

- "Style this in the Airbnb way", "make it feel like Linear", "Vercel-style landing page".
- User mentions a brand or product by name and asks for visual treatment.
- You are about to call `frontend-design` or `impeccable` and the user has named a reference brand.

## How to use

1. List available brands:
   ```bash
   ls ~/.config/opencode/external/awesome-design-md/design-md/
   ```
2. Read the brand's `design.md`:
   ```
   ~/.config/opencode/external/awesome-design-md/design-md/<brand>/design.md
   ```
3. Treat that file as the authoritative design spec for the task. Honor its tokens (color, type scale, spacing, radius, motion, voice) exactly.
4. If multiple brands are referenced, load each and clearly state which tokens come from which.

## Catalog (71 entries)

airbnb, airtable, apple, binance, bmw, bmw-m, bugatti, cal, claude, clay, clickhouse, cohere, coinbase, composio, cursor, elevenlabs, expo, ferrari, figma, framer, hashicorp, ibm, intercom, kraken, lamborghini, linear.app, lovable, mastercard, meta, minimax, mistral, mongodb, notion, openai, opensea, perplexity, pixar, polestar, porsche, posthog, qatar-airways, raycast, replicate, resend, retool, revolut, rolls-royce, scale-ai, shopify, slack, snowflake, spotify, stripe, supabase, tesla, tiktok, together-ai, twilio, uber, vercel, visa, voltagent, webflow, wise, xai, zapier, zara, zoho, zoom.

(Run `ls ~/.config/opencode/external/awesome-design-md/design-md/` for the live list — entries may be added upstream after sync.)

## Source

- Upstream: https://github.com/VoltAgent/awesome-design-md
- Local mirror: `~/.config/opencode/external/awesome-design-md/` (shallow clone)
- To refresh: `cd ~/.config/opencode/external/awesome-design-md && git pull --depth 1`
