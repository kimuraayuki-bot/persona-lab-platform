export const metadata = {
  title: "Terms of Use | Persona Lab",
  description: "Persona Lab Web の利用規約"
};

export default function TermsPage() {
  return (
    <main className="stack">
      <section className="card legal-page">
        <span className="badge">Terms of Use</span>
        <h1 className="title">利用規約</h1>
        <p className="legal-meta">最終更新日: 2026年3月10日</p>
        <p className="subtle">
          Persona Lab Web を利用するすべての方は、本規約に同意したものとみなします。
        </p>
      </section>

      <section className="card legal-page">
        <section className="legal-section">
          <h2>1. サービス内容</h2>
          <p className="subtle">
            当サービスは、作成者が配布した診断リンクを通じて、利用者がブラウザ上で回答し結果を確認する機能を提供します。
          </p>
        </section>

        <section className="legal-section">
          <h2>2. 禁止事項</h2>
          <ul className="bullet-list">
            <li>法令または公序良俗に反する行為</li>
            <li>第三者の権利や利益を侵害する行為</li>
            <li>サービスの運営を妨害する行為や不正アクセス</li>
            <li>虚偽情報の送信、なりすまし、システムへの過度な負荷をかける行為</li>
          </ul>
        </section>

        <section className="legal-section">
          <h2>3. 免責事項</h2>
          <p className="subtle">
            当サービスは、継続的な提供、完全性、正確性、特定目的への適合性を保証するものではありません。
            サービス利用により発生した損害について、運営者は故意または重過失がある場合を除き責任を負いません。
          </p>
        </section>

        <section className="legal-section">
          <h2>4. サービス変更・停止</h2>
          <p className="subtle">
            運営上必要と判断した場合、予告なくサービス内容の変更、停止、終了を行うことがあります。
          </p>
        </section>

        <section className="legal-section">
          <h2>5. 規約の改定</h2>
          <p className="subtle">
            本規約は必要に応じて改定されることがあります。改定後は本ページに掲載した時点で効力を生じます。
          </p>
        </section>
      </section>
    </main>
  );
}
