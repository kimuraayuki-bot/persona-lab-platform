const siteUrl = "https://persona-lab-platform.vercel.app";

export default function sitemap() {
  return [
    {
      url: siteUrl,
      lastModified: "2026-03-10"
    },
    {
      url: `${siteUrl}/privacy`,
      lastModified: "2026-03-10"
    },
    {
      url: `${siteUrl}/ranking`,
      lastModified: "2026-03-10"
    },
    {
      url: `${siteUrl}/terms`,
      lastModified: "2026-03-10"
    },
    {
      url: `${siteUrl}/contact`,
      lastModified: "2026-03-10"
    }
  ];
}
