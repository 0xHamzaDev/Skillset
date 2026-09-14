import raw from "../../../catalog/catalog.json";

export type Localized = { en: string; ar: string };

export type Skill = {
  id: string;
  title: string;
  name: string;
  description: string;
  author: string;
  tags: string[];
  source: { kind: "github"; owner: string; repo: string; ref: string; path: string };
};

export type Bundle = {
  id: string;
  symbol: string;
  name: Localized;
  tagline: Localized;
  why: Localized;
  skills: string[];
  tags: string[];
};

export const catalog = raw as { version: number; updatedAt: string; skills: Skill[]; bundles: Bundle[] };

const byId = new Map(catalog.skills.map((skill) => [skill.id, skill]));

export const bundleSkills = (bundle: Bundle) => bundle.skills.flatMap((id) => byId.get(id) ?? []);

export const bundlesWith = (skill: Skill) => catalog.bundles.filter((bundle) => bundle.skills.includes(skill.id));

const tagCounts = catalog.skills
  .flatMap((skill) => skill.tags)
  .reduce<Record<string, number>>((acc, tag) => ({ ...acc, [tag]: (acc[tag] ?? 0) + 1 }), {});

export const tags = Object.entries(tagCounts)
  .filter(([, count]) => count > 1)
  .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
  .slice(0, 12)
  .map(([tag]) => tag);

export const npxCommand = (skill: Skill) =>
  `npx skills add ${skill.source.owner}/${skill.source.repo} --skill ${skill.name}`;

export const sourceUrl = (skill: Skill) =>
  `https://github.com/${skill.source.owner}/${skill.source.repo}/tree/${skill.source.ref}/${skill.source.path}`;

export const lede = (text: string) => {
  const first = text.match(/^[\s\S]*?[.!?](?=\s|$)/)?.[0] ?? text;
  return text.length - first.length > 120 ? first : text;
};
