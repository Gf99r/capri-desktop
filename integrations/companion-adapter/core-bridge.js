'use strict';

const ASSISTANTS = Object.freeze({
  claude: 'Claude Code',
  codex: 'Codex',
  agy: 'Antigravity',
});

function clean(value, max = 48) {
  return String(value || '')
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max);
}

function summarizeEvent(evt, assistantId) {
  if (!evt || typeof evt !== 'object') return '';
  const assistant = ASSISTANTS[assistantId] || 'Coding agent';
  const eventName = clean(evt.hook_event_name || evt.type || 'activity', 40);
  const toolName = clean(evt.tool_name || evt.toolName || '', 36);
  return [assistant, eventName, toolName].filter(Boolean).join(' · ').slice(0, 150);
}

async function forwardCodingEvent(evt, options = {}) {
  const token = clean(options.token, 128);
  if (!token) return false;

  const message = summarizeEvent(evt, options.assistant);
  if (!message) return false;

  const port = Number.isInteger(options.port) && options.port > 0 && options.port < 65536
    ? options.port : 47824;

  try {
    const response = await fetch(`http://127.0.0.1:${port}/event`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-capri-token': token,
      },
      body: JSON.stringify({ message }),
      signal: AbortSignal.timeout(1200),
    });
    return response.ok;
  } catch {
    return false;
  }
}

module.exports = { summarizeEvent, forwardCodingEvent };
