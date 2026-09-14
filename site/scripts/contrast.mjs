import { light, dark, accent } from "../src/tokens.ts";

const AA = 4.5;

const channel = (v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);

const luminance = (hex) => {
  const [r, g, b] = [1, 3, 5].map((i) => channel(parseInt(hex.slice(i, i + 2), 16) / 255));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};

const ratio = (a, b) => {
  const [x, y] = [luminance(a), luminance(b)].sort((m, n) => n - m);
  return (x + 0.05) / (y + 0.05);
};

const pairs = (theme, palette, ink) =>
  ["fg", "fgMuted", "fgSubtle"]
    .flatMap((fg) => ["bg", "bgSubtle", "bgInset"].map((bg) => [`${theme} ${fg} on ${bg}`, palette[fg], palette[bg]]))
    .concat(["bg", "bgSubtle", "bgInset"].map((bg) => [`${theme} accent on ${bg}`, ink, palette[bg]]))
    .concat([[`${theme} onFill on fill`, palette.onFill, palette.fill]]);

const failures = [...pairs("light", light, accent.light), ...pairs("dark", dark, accent.dark)].filter(([, a, b]) => ratio(a, b) < AA);

for (const [name, a, b] of failures) console.error(`FAIL ${ratio(a, b).toFixed(2)}:1  ${name}  ${a} on ${b}`);

if (failures.length) process.exit(1);
console.log("contrast: every text pair clears WCAG AA");
