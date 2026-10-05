import { defineSchema, defineTable } from 'convex/server';
import { v } from 'convex/values';

export default defineSchema({
  rooms: defineTable({
    code: v.string(), hostToken: v.string(), started: v.boolean(), expiresAt: v.number(),
    peers: v.array(v.object({ slot: v.number(), token: v.string(), offer: v.string(), answer: v.optional(v.string()) })),
  }).index('by_code', ['code']),
});
