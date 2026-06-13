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
- **Android APK:** download the latest `lucky-ludo.apk` from the repo
  **Releases** page and install it on your phone (see *📱 Android APK* below).

## 📱 Android APK

The game ships as an installable Android app — a thin native **WebView** shell
(in `android/`) around the same `index.html`, so the web and app versions never
drift. The **Build Android APK** workflow (`.github/workflows/android.yml`)
compiles a debug APK and attaches it to a GitHub Release.

**Get the APK on your phone:**

1. Open the repo **Releases** page → latest **Lucky Ludo APK** release.
2. Download `lucky-ludo.apk` and tap it; allow installing from this source if
   prompted. (It's a debug build signed with the standard Android debug key.)

**Builds happen automatically** whenever `index.html` or anything under
`android/` changes on `main`; the APK is (re)published to the fixed
`apk-latest` Release at:
`https://github.com/richardruoro/Lucky-Ludo/releases/latest`

You can also build on demand from the Actions tab → **Build Android APK** →
**Run workflow**.

> The app needs internet on first load (Tailwind / icons / fonts come from CDNs).

## 🎮 How to play

1. Open the game — the **Match Lobby** lets you set each colour to Human,
   Computer AI, or Disabled (minimum 2 active players).
2. Adjust each player's **stake** in the Stakes &amp; Wallet panel — each player
   carries a running **wallet balance** that settles after every match.
3. Press **▶ Play** for a normal match where you take your own turns, or
   **⏩ Simulate** to let the AI rush the whole game to a result in seconds.
4. **Tap the dice** to roll. Roll a **6** to bring a token out of its yard.
5. Land on an opponent (off a safe ★ square) to **capture** it back to base.
6. Get all four tokens home first to **win** the pot.
7. Use the **🔊 Sound** button in the header to mute/unmute all audio + voice.

On desktop the dice and controls sit **beside** the board and the layout uses
the full width; on mobile everything stacks and the dice drops **below** it.

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
  Verified fair via Monte Carlo: a uniform 1–6 dice, every game terminates,
  and wins land ~25% per seat with no positional bias.
- **Turbo Simulate** — collapses all animation/turn delays and teleports
  pieces so a full ~400-roll match resolves in a few seconds.
- **Wallets** — per-player balances that escrow stakes and settle winnings,
  refunds and KRA taxes when a match resolves.
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
