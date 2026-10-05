// Integration checks against a real deployed Convex backend. Test room removed in finally.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { ConvexHttpClient } from 'convex/browser';
import { anyApi } from 'convex/server';
const client = new ConvexHttpClient(process.env.CONVEX_URL);
const api = anyApi.rooms, token = randomUUID();
const room = await client.mutation(api.create, { token });
try {
  assert.match(room.code, /^[A-Z2-9]{6}$/);
  assert.equal(await client.query(api.watch, { id: room.id, token: randomUUID() }), null);
  await assert.rejects(client.mutation(api.lock, { id: room.id, token: randomUUID() }));
  await assert.rejects(client.mutation(api.join, { code: room.code, token: randomUUID(), offer: 'invalid' }));
  const guests = [];
  for (let i = 1; i <= 3; i++) {
    const guestToken = randomUUID();
    const result = await client.mutation(api.join, { code: room.code, token: guestToken, offer: 'v=0\r\n' });
    assert.equal(result.slot, i); guests.push(guestToken);
  }
  await assert.rejects(client.mutation(api.join, { code: room.code, token: randomUUID(), offer: 'v=0\r\n' }));
  const own = await client.query(api.watch, { id: room.id, token: guests[0] });
  assert.equal(own.peers.length, 1); assert.equal(own.peers[0].offer, undefined); assert.equal(own.peers[0].token, undefined);
  await client.mutation(api.answer, { id: room.id, token, slot: 1, answer: 'v=0\r\n' });
  assert.equal((await client.query(api.watch, { id: room.id, token: guests[0] })).peers[0].answer, 'v=0\r\n');
  await client.mutation(api.leave, { id: room.id, token: guests[2] });
  await client.mutation(api.lock, { id: room.id, token });
  await assert.rejects(client.mutation(api.join, { code: room.code, token: randomUUID(), offer: 'v=0\r\n' }));
  console.log('PASS: live room creation, capability isolation, input validation, slots/full room, SDP answer, leave, match lock');
} finally {
  await client.mutation(api.leave, { id: room.id, token });
  assert.equal(await client.query(api.watch, { id: room.id, token }), null);
}
