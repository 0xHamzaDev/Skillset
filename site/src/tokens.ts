export const light = {
  bg: "#FAF8F5", bgSubtle: "#FFFFFF", bgInset: "#F0ECE6",
  line: "#E4DED6", lineStrong: "#CBC2B8",
  fg: "#292725", fgMuted: "#625D57", fgSubtle: "#6C655E",
  fill: "#292725", onFill: "#FFFFFF",
} as const;

export const dark = {
  bg: "#191817", bgSubtle: "#232220", bgInset: "#2B2926",
  line: "#3A3733", lineStrong: "#575149",
  fg: "#F8F5F0", fgMuted: "#C4BBB1", fgSubtle: "#B5ABA0",
  fill: "#F8F5F0", onFill: "#292725",
} as const;

export const accent = {
  light: "#A13E0C", dark: "#FFA86D",
  softLight: "#FFE1CB", softDark: "#493023",
  lineLight: "#E6B394", lineDark: "#8D5430",
} as const;
