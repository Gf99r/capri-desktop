'use strict';

const fs = require('node:fs');
const path = require('node:path');

const OLD_IMPORT = "const { createBridge } = require('./bridge');";
const NEW_IMPORT = OLD_IMPORT + "\nconst { forwardCodingEvent } = require('./core-bridge');";
const OLD_DEV = "const DEV = process.argv.includes('--dev');";
const NEW_DEV = OLD_DEV + "\nconst CORE_MODE = process.env.CAPRI_CORE_MODE === '1';";
const OLD_MAIN_BLOCK = "    registerIpc();\n    createOverlay();\n    createTray();\n    windowWatch = startWindowWatch({\n      overlay,\n      onUpdate: (data) => {\n        // a click on the taskbar brings it up over her: sitting on it, her legs would vanish behind it\n        if (data.taskbar && !lastWindows?.taskbar && config.load().rest === 'taskbar') raiseOverlay();\n        lastWindows = data;\n        overlay?.webContents.send('windows:update', data);\n      },\n    });\n    createBridge({\n      port: PORT,\n      // her own Claude Code chat's hooks would cover its answer with theirs\n      onEvent: (evt) => !llm.isChatSession(evt.session_id) && overlay?.webContents.send('claude:event', evt),\n      onDebug: DEV ? debugHandler : null,\n    });\n    globalShortcut.register('Control+Alt+C', () => toggleVisible());\n    llm.restoreClaude(readMemory().claude);\n    refreshModels(); // for her menu's model list\n    setTimeout(() => launch.launchables().catch(() => {}), 20000); // what she can open, before you ask\n    // a screen plugged in, unplugged, or rearranged: her window fitted again, and she learns of it\n    const screensChanged = () => {\n      fitOverlay();\n      windowWatch?.refresh();\n      rebuildTray();\n      sendCommand('screens');\n    };\n    screen.on('display-metrics-changed', screensChanged);\n    screen.on('display-added', screensChanged);\n    screen.on('display-removed', screensChanged);\n    // after sleep or a locked screen, once Windows has settled\n    powerMonitor.on('resume', () => setTimeout(rearmOverlay, 2000));\n    powerMonitor.on('unlock-screen', () => setTimeout(rearmOverlay, 1000));";
const NEW_MAIN_BLOCK = "    if (!CORE_MODE) {\n      registerIpc();\n      createOverlay();\n      createTray();\n      windowWatch = startWindowWatch({\n        overlay,\n        onUpdate: (data) => {\n          if (data.taskbar && !lastWindows?.taskbar && config.load().rest === 'taskbar') raiseOverlay();\n          lastWindows = data;\n          overlay?.webContents.send('windows:update', data);\n        },\n      });\n    }\n    createBridge({\n      port: PORT,\n      onEvent: (evt) => {\n        if (llm.isChatSession(evt.session_id)) return;\n        overlay?.webContents.send('claude:event', evt);\n        if (CORE_MODE) {\n          void forwardCodingEvent(evt, {\n            token: process.env.CAPRI_BRIDGE_TOKEN,\n            port: Number(process.env.CAPRI_CORE_PORT) || 47824,\n            assistant: activeAssistant().id,\n          });\n        }\n      },\n      onDebug: DEV ? debugHandler : null,\n    });\n    if (!CORE_MODE) {\n      globalShortcut.register('Control+Alt+C', () => toggleVisible());\n      llm.restoreClaude(readMemory().claude);\n      refreshModels();\n      setTimeout(() => launch.launchables().catch(() => {}), 20000);\n      const screensChanged = () => {\n        fitOverlay();\n        windowWatch?.refresh();\n        rebuildTray();\n        sendCommand('screens');\n      };\n      screen.on('display-metrics-changed', screensChanged);\n      screen.on('display-added', screensChanged);\n      screen.on('display-removed', screensChanged);\n      powerMonitor.on('resume', () => setTimeout(rearmOverlay, 2000));\n      powerMonitor.on('unlock-screen', () => setTimeout(rearmOverlay, 1000));\n    }";

function replaceExactly(source, before, after, label) {
  const first = source.indexOf(before);
  if (first < 0 || source.indexOf(before, first + before.length) >= 0) {
    throw new Error('CAPRI companion adapter could not uniquely locate ' + label + '. The pinned companion source may have changed.');
  }
  return source.slice(0, first) + after + source.slice(first + before.length);
}

function patchMain(input) {
  const originalEol = input.includes('\r\n') ? '\r\n' : '\n';
  let source = input.replace(/\r\n/g, '\n');
  if (source.includes("const { forwardCodingEvent } = require('./core-bridge');")) {
    if (!source.includes("const CORE_MODE = process.env.CAPRI_CORE_MODE === '1';")) {
      throw new Error('CAPRI companion adapter is only partially installed.');
    }
    return input;
  }
  source = replaceExactly(source, OLD_IMPORT, NEW_IMPORT, 'the bridge import');
  source = replaceExactly(source, OLD_DEV, NEW_DEV, 'the core-mode flag');
  source = replaceExactly(source, OLD_MAIN_BLOCK, NEW_MAIN_BLOCK, 'the main-process startup block');
  source = replaceExactly(source, '    globalShortcut.unregisterAll();', '    if (!CORE_MODE) globalShortcut.unregisterAll();', 'the shutdown handler');
  return source.replace(/\n/g, originalEol);
}

function apply(companionRoot, adapterPath) {
  const mainPath = path.join(companionRoot, 'src', 'main', 'main.js');
  const source = fs.readFileSync(mainPath, 'utf8');
  const patched = patchMain(source);
  if (patched !== source) fs.writeFileSync(mainPath, patched, 'utf8');
  fs.copyFileSync(adapterPath, path.join(companionRoot, 'src', 'main', 'core-bridge.js'));
}

if (require.main === module) {
  const [companionRoot, adapterPath] = process.argv.slice(2);
  if (!companionRoot || !adapterPath) {
    process.stderr.write('Usage: node apply-companion-adapter.cjs <companion-root> <core-bridge.js>\n');
    process.exitCode = 2;
  } else {
    try {
      apply(path.resolve(companionRoot), path.resolve(adapterPath));
      process.stdout.write('CAPRI companion adapter is ready.\n');
    } catch (error) {
      process.stderr.write(error.message + '\n');
      process.exitCode = 1;
    }
  }
}

module.exports = { apply, patchMain, OLD_IMPORT, OLD_DEV, OLD_MAIN_BLOCK };
