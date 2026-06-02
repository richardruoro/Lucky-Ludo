# 🎲 Lucky Ludo — Wooden Classic (P2P Stakes)

A single-file, browser-based Ludo game with a classic wooden board, 3D dice,
a smart computer opponent, a per-player "phone screen" simulator, and a
✨ live commentator that hypes the match in Kenyan sheng (with voice).

> Built as a stakes-match prototype. The staking / payout figures are a
> **simulation** for demonstrating the P2P + tax flow — no real money moves.

## ▶️ Play

- **Live (GitHub Pages):** published automatically on every merge to `main`.
  The URL appears in the **CD — Deploy to GitHub Pages** workflow run
  (Actions tab → latest deploy → environment URL), and is typically:
  `https://richardruoro.github.io/Lucky-Ludo/`
- **Locally:** just open `index.html` in any modern browser.

## 🎮 How to play

1. Open the game — the **Match Lobby** lets you set each colour to Human,
   Computer AI, or Disabled (minimum 2 active players).
2. Adjust each player's **stake** in the Variable Stakes panel.
3. **Tap the dice** to roll. Roll a **6** to bring a token out of its yard.
4. Land on an opponent (off a safe ★ square) to **capture** it back to base.
5. Get all four tokens home first to **win** the pot.
6. Flip **AI Autopilot** to watch the computers play it out themselves.

## ✨ AI Commentator

The commentator works **fully offline** using a local sheng phrase engine and
the browser's built-in speech synthesis. To use the real model, paste a Google
AI Studio key into `GEMINI_API_KEY` near the top of the script in `index.html`
— it will call `gemini-2.0-flash` and gracefully fall back to the offline
engine if the request fails, so the game never breaks.

## 🧱 Architecture

Everything lives in `index.html`:

- **Board model** — a 52-cell shared track (`TRACK_COORDS`) plus per-colour
  yards, home columns and goals. `getTokenCoords()` maps a token's step
  (`0` = yard, `1–51` = track, `52–56` = home column, `57` = home) to a grid
  cell.
- **Rules engine** — rolling, eligible-move detection, animated hops,
  captures, safe squares, three-sixes forfeit, and extra turns on 6 / capture.
- **Computer AI** — scores moves (finish > capture > leave base > advance).
- **Payout matrix** — platform fee, KRA excise & withholding tax, and a
  second-place safety-net refund, shown from each player's perspective.

## 🔁 CI / CD

- **CI** (`.github/workflows/ci.yml`) — on every PR/branch push, validates that
  the inline game script parses and that the previously-missing functions
  (`AudioController`, `requestGeminiCommentary`, `generateCustomTrashTalk`)
  are present. Run it locally with `node scripts/check-syntax.js`.
- **CD** (`.github/workflows/deploy.yml`) — on merge to `main`, publishes the
  site to GitHub Pages.

> **One-time setup:** in the repo **Settings → Pages**, set **Source** to
> **GitHub Actions** (the deploy workflow also attempts to enable this
> automatically).

## 🚧 Roadmap

- Real online multiplayer (P2P / server-backed) so players gamble against each
  other live.
- Wallet + M-Pesa integration for actual deposits and payouts.
