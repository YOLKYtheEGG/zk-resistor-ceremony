#!/usr/bin/env node
// Validates transcript/contributions.json:
//   - every entry has stage "phase1" or "phase2" and a numeric slot
//   - within each stage, slots form a contiguous run from 0 (no gaps)
//   - names match [a-zA-Z0-9_-]{1,32}
//   - hashes match sha256:<64-hex>
//   - phase1 entries carry ptau (-> phase1/) + ptau_hash
//   - phase2 entries carry insert_zkey + withdraw_zkey (-> phase2/) + hashes
//   - attestation is null or a string pointing into contributors/
//   - drand-beacon entries carry a numeric drand_round
//
// Used by .github/workflows/verify-contribution.yml on every PR.

import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..");
const t = JSON.parse(
  await readFile(join(repoRoot, "transcript", "contributions.json"), "utf8"),
);

function die(msg) {
  console.error(msg);
  process.exit(1);
}

const SHA = /^sha256:[0-9a-f]{64}$/;
const NAME = /^[a-zA-Z0-9_-]{1,32}$/;

if (!Array.isArray(t.contributions)) die("contributions must be an array");

const slots = { phase1: [], phase2: [] };

for (const c of t.contributions) {
  if (c.stage !== "phase1" && c.stage !== "phase2") {
    die(`bad stage: ${JSON.stringify(c.stage)}`);
  }
  if (typeof c.slot !== "number") die(`${c.stage}: slot must be a number`);
  if (!NAME.test(c.name)) die(`bad name: ${c.name}`);
  slots[c.stage].push(c.slot);

  if (
    c.attestation !== null &&
    (typeof c.attestation !== "string" ||
      !c.attestation.startsWith("contributors/"))
  ) {
    die(`${c.stage} slot ${c.slot}: attestation must be null or point into contributors/`);
  }
  if (c.name === "drand-beacon" && typeof c.drand_round !== "number") {
    die(`drand-beacon ${c.stage} slot ${c.slot}: missing numeric drand_round`);
  }

  if (c.stage === "phase1") {
    if (typeof c.ptau !== "string" || !c.ptau.startsWith("phase1/")) {
      die(`phase1 slot ${c.slot}: ptau must point into phase1/`);
    }
    if (!SHA.test(c.ptau_hash)) die(`phase1 slot ${c.slot}: bad ptau_hash`);
  } else {
    if (typeof c.insert_zkey !== "string" || !c.insert_zkey.startsWith("phase2/")) {
      die(`phase2 slot ${c.slot}: insert_zkey must point into phase2/`);
    }
    if (typeof c.withdraw_zkey !== "string" || !c.withdraw_zkey.startsWith("phase2/")) {
      die(`phase2 slot ${c.slot}: withdraw_zkey must point into phase2/`);
    }
    if (!SHA.test(c.insert_zkey_hash)) die(`phase2 slot ${c.slot}: bad insert_zkey_hash`);
    if (!SHA.test(c.withdraw_zkey_hash)) die(`phase2 slot ${c.slot}: bad withdraw_zkey_hash`);
  }
}

for (const stage of ["phase1", "phase2"]) {
  const seen = new Set();
  for (const s of slots[stage]) {
    if (seen.has(s)) die(`${stage}: duplicate slot ${s}`);
    seen.add(s);
  }
  const sorted = [...seen].sort((a, b) => a - b);
  for (let i = 0; i < sorted.length; i++) {
    if (sorted[i] !== i) die(`${stage}: slot gap at index ${i} (got ${sorted[i]})`);
  }
}

const n1 = slots.phase1.length;
const n2 = slots.phase2.length;
console.log(`Schema valid: phase1 ${n1} entries, phase2 ${n2} entries.`);
