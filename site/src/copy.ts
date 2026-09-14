const repoUrl = "https://github.com/0xHamzaDev/Skillset";
const releaseUrl = `${repoUrl}/releases`;

export const copy = {
  appName: "Skillset",
  home: "/",
  releaseUrl,
  repoUrl,
  download: "View Mac releases",
  whyLabel: "Why this bundle",
  skillsCount: (n: number) => (n === 1 ? "1 skill" : `${n} skills`),
  openInApp: "Open in Skillset",
  searchPlaceholder: "Search by name or description",
  allTag: "All",
  resultCount: (n: number) => (n === 1 ? "1 result" : `${n} results`),
  showAll: (n: number) => `Show all ${n}`,
  fullDescription: "The full description",
  install: "Install",
  copy: "Copy",
  copied: "Copied",
  orCli: "Or from the terminal",
  noResults: "No skill matches your search.",
  clearFilters: "Clear filters",
  by: "by",
  skillLabel: "Skill",
  bundleLabel: "Bundle",
  includedIn: "Included in",
  includes: "Skills in this bundle",
  allSkills: "All skills",
  allBundles: "All bundles",
  metaDescription:
    "A native Mac app that finds installed agent skills, installs and updates new ones, and installs whole bundles in one action.",
} as const;
