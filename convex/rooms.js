import { mutation, query, internalMutation } from './_generated/server.js';
import { internal } from './_generated/api.js';
import { v, ConvexError } from 'convex/values';

const lifetime = 4 * 60 * 60 * 1000;
function tokenValid(token) {
  if (!/^[a-f0-9-]{36}$/.test(token)) throw new ConvexError('Invalid room credentials.');
}
function sdpValid(sdp) {
  if (sdp.length > 18000 || !sdp.startsWith('v=0')) throw new ConvexError('Invalid connection offer.');
}
async function active(ctx, id) {
  const room = await ctx.db.get(id);
  if (!room || room.expiresAt < Date.now()) throw new ConvexError('This room has closed. Create a new room.');
  return room;
}
function host(room, token) {
  if (room.hostToken !== token) throw new ConvexError('Only the host can do this.');
}
export const create = mutation({
  args: { token: v.string() },
  handler: async (ctx, { token }) => {
    tokenValid(token);
    // Bound storage/work for this free playtest service. Expired rooms are removed automatically.
    if ((await ctx.db.query('rooms').take(129)).length >= 128) throw new ConvexError('Rooms are busy. Try again later.');
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code;
    for (let attempt = 0; attempt < 8; attempt++) {
      code = Array.from({ length: 6 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join('');
      if (!(await ctx.db.query('rooms').withIndex('by_code', q => q.eq('code', code)).unique())) break;
      code = undefined;
    }
    if (!code) throw new ConvexError('Could not make a room. Try again.');
    const id = await ctx.db.insert('rooms', { code, hostToken: token, started: false, expiresAt: Date.now() + lifetime, peers: [] });
    await ctx.scheduler.runAfter(lifetime, internal.rooms.expire, { id });
    return { id, code, slot: 0 };
  },
});
export const join = mutation({
  args: { code: v.string(), token: v.string(), offer: v.string() },
  handler: async (ctx, { code, token, offer }) => {
    tokenValid(token); sdpValid(offer);
    if (!/^[A-Z2-9]{6}$/.test(code)) throw new ConvexError('Enter the six-character room code.');
    const found = await ctx.db.query('rooms').withIndex('by_code', q => q.eq('code', code)).unique();
    if (!found) throw new ConvexError('Room not found. Check the code.');
    const room = await active(ctx, found._id);
    if (room.started) throw new ConvexError('The match has started. Ask the host for a new room.');
    if (room.peers.length >= 3) throw new ConvexError('This room is full (four players).');
    const slot = [1, 2, 3].find(i => !room.peers.some(p => p.slot === i));
    await ctx.db.patch(room._id, { peers: [...room.peers, { slot, token, offer }] });
    return { id: room._id, code, slot };
  },
});
export const watch = query({
  args: { id: v.id('rooms'), token: v.string() },
  handler: async (ctx, { id, token }) => {
    const room = await ctx.db.get(id);
    if (!room || room.expiresAt < Date.now()) return null;
    if (room.hostToken === token) return { started: room.started, peers: room.peers.map(p => ({ slot: p.slot, offer: p.offer, answer: p.answer })) };
    const own = room.peers.find(p => p.token === token);
    if (!own) return null;
    return { started: room.started, peers: [{ slot: own.slot, answer: own.answer }] };
  },
});
export const answer = mutation({
  args: { id: v.id('rooms'), token: v.string(), slot: v.number(), answer: v.string() },
  handler: async (ctx, args) => {
    const room = await active(ctx, args.id); host(room, args.token); sdpValid(args.answer);
    if (!room.peers.some(p => p.slot === args.slot)) throw new ConvexError('Player left.');
    await ctx.db.patch(args.id, { peers: room.peers.map(p => p.slot === args.slot ? { ...p, answer: args.answer } : p) });
  },
});
export const lock = mutation({
  args: { id: v.id('rooms'), token: v.string() },
  handler: async (ctx, args) => { const room = await active(ctx, args.id); host(room, args.token); await ctx.db.patch(args.id, { started: true }); },
});
export const leave = mutation({
  args: { id: v.id('rooms'), token: v.string() },
  handler: async (ctx, args) => {
    const room = await ctx.db.get(args.id);
    if (!room) return;
    if (room.hostToken === args.token) await ctx.db.delete(args.id);
    else if (room.peers.some(p => p.token === args.token)) await ctx.db.patch(args.id, { peers: room.peers.filter(p => p.token !== args.token) });
  },
});
export const expire = internalMutation({
  args: { id: v.id('rooms') },
  handler: async (ctx, { id }) => { if (await ctx.db.get(id)) await ctx.db.delete(id); },
});
