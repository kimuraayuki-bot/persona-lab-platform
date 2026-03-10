import Link from "next/link";

const features = [
  {
    title: "ブラウザだけで回答",
    body: "作成者から届いたURLを開くだけで、アプリを入れなくても診断に参加できます。"
  },
  {
    title: "タイプ結果を即時表示",
    body: "回答完了後に結果コード、要約、タイプ別の説明をその場で確認できます。"
  },
  {
    title: "iPhoneアプリと連携",
    body: "診断作成や管理は iPhone アプリ側で行い、配布先は Web で広く受け取れます。"
  }
];

const steps = [
  {
    title: "作成者が診断を作る",
    body: "診断タイトル、質問、結果プロフィールをアプリで設定します。"
  },
  {
    title: "共有リンクを配布する",
    body: "公開リンクを SNS やメッセージで共有し、回答者はブラウザから参加します。"
  },
  {
    title: "結果を確認して共有する",
    body: "回答者は結果ページでタイプを確認し、共有文コピーやアプリ起動に進めます。"
  }
];

const faqs = [
  {
    question: "このサイトで診断は作れますか？",
    answer: "診断の作成と管理は iPhone アプリで行います。Web は回答と結果確認に特化しています。"
  },
  {
    question: "回答者はアカウント登録が必要ですか？",
    answer: "通常は不要です。受け取った回答リンクからそのまま参加できます。"
  },
  {
    question: "公開リンクが無効になることはありますか？",
    answer: "作成者が診断を削除した場合や、共有トークンが無効になった場合は利用できなくなります。"
  }
];

export default function HomePage() {
  return (
    <main className="stack landing-page">
      <section className="card stack">
        <span className="badge">Persona Lab Web</span>
        <h1 className="title">診断回答をブラウザで受け取るための公開サイトです</h1>
        <p className="subtle">
          Persona Lab は、iPhone アプリで作成したカスタム診断を Web 上で回答できるサービスです。
          招待URL（例: <code>/q/quiz-public-id?token=...</code>）を開くと、このブラウザ上で回答できます。
        </p>
        <div className="row wrap">
          <a className="button ghost" href="myapp://quiz/demo-quiz">
            iPhoneアプリで開く
          </a>
          <Link className="button secondary" href="/q/demo-quiz?token=demo">
            デモ画面を開く
          </Link>
        </div>
      </section>

      <section className="card stack">
        <h2 className="title">できること</h2>
        <div className="feature-grid">
          {features.map((feature) => (
            <article className="feature-card" key={feature.title}>
              <h3>{feature.title}</h3>
              <p className="subtle">{feature.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="card stack">
        <h2 className="title">利用の流れ</h2>
        <ol className="step-list">
          {steps.map((step, index) => (
            <li className="step-item" key={step.title}>
              <span className="step-badge">{index + 1}</span>
              <div className="stack compact">
                <h3>{step.title}</h3>
                <p className="subtle">{step.body}</p>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <section className="card stack">
        <h2 className="title">公開情報</h2>
        <p className="subtle">
          サービスの利用条件、プライバシー方針、問い合わせ先は以下で公開しています。
        </p>
        <div className="link-grid">
          <Link className="link-card" href="/privacy">
            <strong>Privacy Policy</strong>
            <span className="subtle">取得する情報と利用目的を掲載しています。</span>
          </Link>
          <Link className="link-card" href="/terms">
            <strong>Terms of Use</strong>
            <span className="subtle">利用条件、禁止事項、免責事項を掲載しています。</span>
          </Link>
          <Link className="link-card" href="/contact">
            <strong>Contact</strong>
            <span className="subtle">運営への連絡先と問い合わせ方法を掲載しています。</span>
          </Link>
        </div>
      </section>

      <section className="card stack">
        <h2 className="title">よくある質問</h2>
        <div className="faq-list">
          {faqs.map((faq) => (
            <article className="faq-item" key={faq.question}>
              <h3>{faq.question}</h3>
              <p className="subtle">{faq.answer}</p>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
