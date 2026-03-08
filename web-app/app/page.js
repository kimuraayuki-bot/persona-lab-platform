import Link from "next/link";

export default function HomePage() {
  return (
    <main className="stack">
      <section className="card stack">
        <span className="badge">Persona Lab Web</span>
        <h1 className="title">回答リンクから診断に参加できます</h1>
        <p className="subtle">
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
    </main>
  );
}
