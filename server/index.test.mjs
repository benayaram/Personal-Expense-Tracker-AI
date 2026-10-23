import test from 'node:test';
import assert from 'node:assert/strict';
import {createCoachServer, validateRequest} from './index.mjs';
const token = 'unit-test-only-token-0000000000000000';
const input = () => ({question: 'How can I save?', summary: {currency: 'INR', monthIncomePaise: 6000000,
  monthExpensesPaise: 3250000, trackedBalancePaise: 2750000, reservedBillsPaise: 750000,
  plannedSavingsPaise: 1000000, categorySpendingPaise: {Dining: 580000}, budgetsPaise: {Dining: 400000}, goals: []}});
async function withServer(options, fn) {
  const server = createCoachServer({token, apiKey: 'test-not-a-real-key', ...options});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try { await fn(`http://127.0.0.1:${server.address().port}`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
const post = (url, body, auth = token) => fetch(`${url}/v1/coach`, {method: 'POST',
  headers: {'Authorization': `Bearer ${auth}`, 'Content-Type': 'application/json'}, body: JSON.stringify(body)});
test('rejects malformed and noninteger financial summaries', () => {
  assert.ok(validateRequest(input()));
  const a = input(); a.summary.monthIncomePaise = 1.1; assert.equal(validateRequest(a), false);
  const b = input(); b.summary.categorySpendingPaise.Dining = -1; assert.equal(validateRequest(b), false);
  assert.equal(validateRequest({}), false);
});
test('requires secure deployment configuration', () => {
  assert.throws(() => createCoachServer({token: 'short', apiKey: 'x'}));
  assert.throws(() => createCoachServer({token}));
});
test('health and authorization do not call upstream', async () => withServer({fetchImpl: () => { throw Error('must not call'); }}, async url => {
  assert.equal((await fetch(`${url}/healthz`)).status, 200);
  assert.equal((await post(url, input(), 'wrong')).status, 401);
  assert.equal((await post(url, {})).status, 400);
  assert.equal((await fetch(`${url}/v1/coach`)).status, 405);
  assert.equal((await fetch(`${url}/missing`)).status, 404);
}));
test('sends paise summary and system instruction; strips arbitrary extra fields', async () => {
  let upstream;
  await withServer({fetchImpl: async (url, options) => {
    upstream = {url, options};
    return Response.json({candidates: [{content: {parts: [{text: 'Review your dining budget.'}]}}]});
  }}, async url => {
    const body = input(); body.notificationText = 'private'; body.summary.accountNumber = 'private';
    const response = await post(url, body); assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {answer: 'Review your dining budget.'});
    const payload = JSON.parse(upstream.options.body);
    assert.ok(payload.systemInstruction.parts[0].text.includes('100 paise = INR 1'));
    assert.ok(!upstream.options.body.includes('private'));
    assert.equal(upstream.options.headers['x-goog-api-key'], 'test-not-a-real-key');
    assert.ok(upstream.url.startsWith('https://generativelanguage.googleapis.com/'));
  });
});
test('provider errors do not disclose provider response or secrets', async () => withServer({fetchImpl: async () => new Response('private error', {status: 403})}, async url => {
  const response = await post(url, input()); assert.equal(response.status, 502);
  assert.ok(!(await response.text()).includes('private'));
}));
test('empty model response fails usefully', async () => withServer({fetchImpl: async () => Response.json({candidates: []})}, async url => {
  assert.equal((await post(url, input())).status, 502);
}));
test('limits authenticated paid requests', async () => withServer({limit: 1, fetchImpl: async () => { throw Error('timeout'); }}, async url => {
  assert.equal((await post(url, input())).status, 502);
  assert.equal((await post(url, input())).status, 429);
}));
test('rejects oversized requests before calling the model', async () => withServer({fetchImpl: async () => { throw Error('must not call'); }}, async url => {
  const response = await post(url, {question: 'x'.repeat(40000)}); assert.equal(response.status, 413);
}));
