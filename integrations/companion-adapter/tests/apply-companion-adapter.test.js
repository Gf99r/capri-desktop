'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { patchMain, OLD_IMPORT, OLD_DEV, OLD_MAIN_BLOCK } = require('../apply-companion-adapter.cjs');

function fixture() {
  return [
    "'use strict';",
    OLD_IMPORT,
    OLD_DEV,
    "function main() {",
    "  app.whenReady().then(() => {",
    OLD_MAIN_BLOCK,
    "  });",
    "  app.on('will-quit', () => {",
    "    globalShortcut.unregisterAll();",
    "    windowWatch?.stop();",
    "  });",
    "}",
  ].join('\n');
}

test('patches the companion into background core mode', () => {
  const patched = patchMain(fixture());
  assert.match(patched, /forwardCodingEvent/);
  assert.match(patched, /CAPRI_CORE_MODE/);
  assert.match(patched, /if \(!CORE_MODE\) \{\s+registerIpc/);
  assert.match(patched, /if \(CORE_MODE\) \{\s+void forwardCodingEvent/);
  assert.match(patched, /if \(!CORE_MODE\) globalShortcut\.unregisterAll/);
  assert.doesNotMatch(patched, /onEvent: \(evt\) => !llm\.isChatSession/);
});

test('is idempotent', () => {
  const once = patchMain(fixture());
  assert.equal(patchMain(once), once);
});

test('rejects an unexpected companion revision instead of applying a partial patch', () => {
  assert.throws(() => patchMain("'use strict';"), /could not uniquely locate/);
});
