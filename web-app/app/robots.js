const siteUrl = "https://persona-lab-platform.vercel.app";

export default function robots() {
  return {
    rules: {
      userAgent: "*",
      allow: "/"
    },
    sitemap: `${siteUrl}/sitemap.xml`,
    host: siteUrl
  };
}
