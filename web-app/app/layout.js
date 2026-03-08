import "./globals.css";

export const metadata = {
  title: "Persona Lab",
  description: "カスタム診断をブラウザで回答"
};

export default function RootLayout({ children }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
