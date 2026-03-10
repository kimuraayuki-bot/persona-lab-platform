export const metadata = {
  title: "Privacy Policy | Persona Lab",
  description: "Persona Lab Web のプライバシーポリシー"
};

export default function PrivacyPage() {
  return (
    <main className="stack">
      <section className="card legal-page">
        <span className="badge">Privacy Policy</span>
        <h1 className="title">プライバシーポリシー</h1>
        <p className="legal-meta">最終更新日: 2026年3月10日</p>
        <p className="subtle">
          Persona Lab Web は、iPhone アプリで作成された診断への回答受付と結果表示を提供するために運営されています。
          本ページでは、当サービスにおける情報の取扱い方針を説明します。
        </p>
      </section>

      <section className="card legal-page">
        <section className="legal-section">
          <h2>1. 取得する情報</h2>
          <ul className="bullet-list">
            <li>診断回答に含まれる選択結果、診断結果、共有に必要なトークン情報</li>
            <li>アクセスログ、利用ブラウザ、IP アドレスなどの技術情報</li>
            <li>お問い合わせ時に利用者が任意で送信する氏名、メールアドレス、本文</li>
          </ul>
        </section>

        <section className="legal-section">
          <h2>2. 利用目的</h2>
          <ul className="bullet-list">
            <li>診断の回答受付、結果表示、共有機能の提供</li>
            <li>ランキング掲載可として公開された診断の一覧表示と回答数集計</li>
            <li>不正利用の防止、障害調査、品質改善</li>
            <li>お問い合わせへの対応</li>
            <li>広告配信および利用状況の分析</li>
          </ul>
        </section>

        <section className="legal-section">
          <h2>3. 外部サービスの利用</h2>
          <p className="subtle">
            本サービスは、ホスティング、データ保存、分析、広告配信のために第三者サービスを利用する場合があります。
            例として、Vercel、Supabase、Google AdSense / Google AdMob などが含まれます。
          </p>
        </section>

        <section className="legal-section">
          <h2>4. 情報の保存期間</h2>
          <p className="subtle">
            取得した情報は、サービス提供および法令対応に必要な期間保存し、不要になった情報は順次削除または匿名化します。
          </p>
        </section>

        <section className="legal-section">
          <h2>5. 利用者の権利</h2>
          <p className="subtle">
            ご本人に関する情報の確認、訂正、削除の希望がある場合は、下記の連絡先までお問い合わせください。
          </p>
        </section>
      </section>
    </main>
  );
}
