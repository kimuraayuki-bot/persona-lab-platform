import Link from "next/link";

export const metadata = {
  title: "メール認証が完了しました | Persona Lab",
  description: "Persona Lab のメール認証完了ページです。"
};

export default function AuthConfirmedPage() {
  return (
    <main className="stack">
      <section className="card stack">
        <span className="badge">Email Verified</span>
        <h1 className="title">メール認証が完了しました</h1>
        <p className="subtle">
          アカウントの確認が完了しました。iPhone アプリに戻って、登録したメールアドレスとパスワードでログインしてください。
        </p>
        <div className="row wrap">
          <a className="button primary" href="myapp://auth/confirmed">
            アプリに戻る
          </a>
          <Link className="button secondary" href="/">
            Webトップへ
          </Link>
        </div>
      </section>

      <section className="card stack">
        <h2 className="title">うまく戻れない場合</h2>
        <p className="subtle">
          そのままアプリを開き直してログインしてください。確認メールのリンクを一度開けていれば、認証は完了していることがあります。
        </p>
      </section>
    </main>
  );
}
