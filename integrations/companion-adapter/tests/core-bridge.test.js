'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { summarizeEvent, forwardCodingEvent } = require('../core-bridge');

test('summarizes supported coding agent events without forwarding prompt or command content', () => {
  const summary = summarizeEvent({
    hook_event_name: 'PreToolUse',
    tool_name: 'Edit',
    tool_input: { file_path: 'C:/private/project/secrets.txt', new_string: 'private content' },
    prompt: 'do something private',
  }, 'claude');

  assert.equal(summary, 'Claude Code · PreToolUse · Edit');
  assert.equal(summary.includes('private'), false);
  assert.equal(summary.includes('secrets'), false);
});

test('labels Codex and Antigravity events', () => {
  assert.equal(summarizeEvent({ type: 'turn.completed' }, 'codex'), 'Codex · turn.completed');
  assert.equal(summarizeEvent({ hook_event_name: 'AfterAgent' }, 'agy'), 'Antigravity · AfterAgent');
});

test('removes control characters and bounds event text', () => {
  const summary = summarizeEvent({ hook_event_name: 'Pre\nToolUse\u0000' + 'x'.repeat(100), tool_name: 'Run\nShell' }, 'claude');
  assert.equal(summary.includes('\n'), false);
  assert.ok(summary.length <= 150);
});

test('does not attempt a network call without the session token', async () => {
  assert.equal(await forwardCodingEvent({ hook_event_name: 'PreToolUse' }, {}), false);
});
