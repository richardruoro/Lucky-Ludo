#!/usr/bin/env node
/**
 * CI guard: extract the inline game script from index.html and make sure it
 * parses. This is exactly the class of failure (an undefined/broken function
 * reference) that previously froze the game, so we fail the build on it.
 */
const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'index.html');
const html = fs.readFileSync(file, 'utf8');

// Grab every bare <script> ... </script> block (ignores <script src="...">).
const blocks = html.match(/<script>[\s\S]*?<\/script>/g) || [];
if (blocks.length === 0) {
  console.error('No inline <script> block found in index.html');
  process.exit(1);
}

let checked = 0;
for (const block of blocks) {
  const code = block.replace(/^<script>/, '').replace(/<\/script>$/, '');
  try {
    // Throws a SyntaxError if the code is malformed.
    // eslint-disable-next-line no-new-func
    new Function(code);
    checked++;
  } catch (err) {
    console.error('Syntax error in inline script:\n' + err.message);
    process.exit(1);
  }
}

// Guard against the previous regression: these must be defined in the script.
const required = [
  'const AudioController',
  'function requestGeminiCommentary',
  'function generateCustomTrashTalk',
  'function getTokenCoords',
];
const missing = required.filter((sig) => !html.includes(sig));
if (missing.length) {
  console.error('Missing required definitions: ' + missing.join(', '));
  process.exit(1);
}

console.log(`OK: ${checked} inline script block(s) parsed, all required definitions present.`);
