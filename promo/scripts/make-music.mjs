// Generates public/music.wav: a calm 23 s pad + pluck loop. Run: node scripts/make-music.mjs
import { writeFileSync } from "node:fs";

const SR = 44100;
const DUR = 23;
const N = SR * DUR;
const L = new Float32Array(N);
const R = new Float32Array(N);
const hz = (midi) => 440 * 2 ** ((midi - 69) / 12);

// Cmaj7, Am7, Fmaj7, G6, then again, ending back home on C
const CHORDS = [
  [48, 52, 55, 59],
  [45, 52, 55, 60],
  [41, 52, 57, 60],
  [43, 50, 55, 64],
  [48, 52, 55, 59],
  [45, 52, 55, 60],
  [41, 52, 57, 60],
  [48, 55, 62, 64],
];
const BAR = DUR / CHORDS.length;

const add = (t0, len, fn) => {
  const a = Math.max(0, Math.floor(t0 * SR));
  const b = Math.min(N, Math.floor((t0 + len) * SR));
  for (let i = a; i < b; i++) {
    const [l, r] = fn((i - a) / SR);
    L[i] += l;
    R[i] += r;
  }
};

CHORDS.forEach((chord, c) => {
  const t0 = c * BAR;
  // pad: two detuned sines per note, slow attack, tail overlapping the next chord
  const padLen = BAR + 1.6;
  chord.forEach((m, k) => {
    const f = hz(m);
    const pan = 0.5 + (k - 1.5) * 0.18;
    add(t0, padLen, (t) => {
      const env = Math.min(1, t / 1.1) * Math.min(1, (padLen - t) / 1.6);
      const s = (Math.sin(2 * Math.PI * f * 1.003 * t) + Math.sin(2 * Math.PI * f * 0.997 * t) + 0.25 * Math.sin(4 * Math.PI * f * t)) * 0.06 * env;
      return [s * (1 - pan), s * pan];
    });
  });
  // bass: the root an octave down
  const fb = hz(chord[0] - 12);
  add(t0, padLen, (t) => {
    const s = Math.sin(2 * Math.PI * fb * t) * 0.16 * Math.min(1, t / 0.4) * Math.min(1, (padLen - t) / 1.6);
    return [s, s];
  });
  // plucks: chord tones two octaves up, with two quieter echoes
  const STEP = BAR / 8;
  [0, 2, 1, 3, 2, 1, 3, 2].forEach((idx, n) => {
    const f = hz(chord[idx] + 24);
    [0, 1, 2].forEach((echo) => {
      const pan = (n + echo) % 2 ? 0.25 : 0.75;
      const gain = 0.11 * 0.4 ** echo;
      add(t0 + n * STEP + echo * STEP * 1.5, 1.4, (t) => {
        const s = (Math.sin(2 * Math.PI * f * t) + 0.3 * Math.sin(4 * Math.PI * f * t)) * Math.exp(-t * 5) * Math.min(1, t / 0.004) * gain;
        return [s * (1 - pan), s * pan];
      });
    });
  });
});

// fades + normalise to -3 dB
let peak = 0;
for (let i = 0; i < N; i++) {
  const t = i / SR;
  const fade = Math.min(1, t / 1.2) * Math.min(1, (DUR - t) / 3);
  L[i] *= fade;
  R[i] *= fade;
  peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
}
const g = 0.7 / peak;

const buf = Buffer.alloc(44 + N * 4);
buf.write("RIFF", 0);
buf.writeUInt32LE(36 + N * 4, 4);
buf.write("WAVEfmt ", 8);
buf.writeUInt32LE(16, 16);
buf.writeUInt16LE(1, 20);
buf.writeUInt16LE(2, 22);
buf.writeUInt32LE(SR, 24);
buf.writeUInt32LE(SR * 4, 28);
buf.writeUInt16LE(4, 32);
buf.writeUInt16LE(16, 34);
buf.write("data", 36);
buf.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) {
  buf.writeInt16LE(Math.round(L[i] * g * 32767), 44 + i * 4);
  buf.writeInt16LE(Math.round(R[i] * g * 32767), 46 + i * 4);
}
writeFileSync(new URL("../public/music.wav", import.meta.url), buf);
console.log("music.wav", (buf.length / 1e6).toFixed(1), "MB, peak before gain", peak.toFixed(2));
