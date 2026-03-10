import "./globals.css";
import SiteFooter from "@/components/SiteFooter";

const adsenseClientId = process.env.NEXT_PUBLIC_ADSENSE_CLIENT_ID;

export const metadata = {
  title: "Persona Lab",
  description: "カスタム診断をブラウザで回答"
};

export default function RootLayout({ children }) {
  return (
    <html lang="ja">
      <head>
        {adsenseClientId ? (
          <script
            async
            crossOrigin="anonymous"
            src={`https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${adsenseClientId}`}
          />
        ) : null}
      </head>
      <body>
        {children}
        <SiteFooter />
      </body>
    </html>
  );
}
