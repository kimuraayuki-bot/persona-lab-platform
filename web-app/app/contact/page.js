export const metadata = {
  title: "Contact | Persona Lab",
  description: "Persona Lab Web のお問い合わせ先"
};

export default function ContactPage() {
  return (
    <main className="stack">
      <section className="card legal-page">
        <span className="badge">Contact</span>
        <h1 className="title">お問い合わせ</h1>
        <p className="legal-meta">最終更新日: 2026年3月10日</p>
        <p className="subtle">
          サービスに関する不具合報告、権利侵害の連絡、掲載内容の修正依頼は、以下の連絡先までお願いします。
        </p>
      </section>

      <section className="card legal-page">
        <div className="contact-box">
          <h2>連絡先メールアドレス</h2>
          <p>
            <a href="mailto:sys@ayukiofumiria.com">sys@ayukiofumiria.com</a>
          </p>
          <p className="subtle">
            送信時は、対象ページ URL、発生日時、利用環境、問い合わせ内容を記載してください。
          </p>
        </div>

        <section className="legal-section">
          <h2>回答について</h2>
          <p className="subtle">
            内容を確認のうえ、必要に応じて返信します。すべてのお問い合わせに対して返信を保証するものではありません。
          </p>
        </section>
      </section>
    </main>
  );
}
