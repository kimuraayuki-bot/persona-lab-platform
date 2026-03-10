import Link from "next/link";

export default function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="site-footer-inner">
        <nav className="footer-nav" aria-label="サイト情報">
          <Link href="/">Home</Link>
          <Link href="/ranking">Ranking</Link>
          <Link href="/privacy">Privacy Policy</Link>
          <Link href="/terms">Terms of Use</Link>
          <Link href="/contact">Contact</Link>
        </nav>
        <p className="footer-copy">Persona Lab Web</p>
      </div>
    </footer>
  );
}
