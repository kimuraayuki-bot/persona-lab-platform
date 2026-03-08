import Link from "next/link";
import QuizRunner from "./quiz-runner";
import { fetchQuizByPublicId } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function QuizAnswerPage({ params, searchParams }) {
  // Next.js 16 treats route params/searchParams as async request APIs.
  const resolvedParams = await params;
  const resolvedSearchParams = await searchParams;
  const quizPublicId = resolvedParams?.quizPublicId;
  const token = typeof resolvedSearchParams?.token === "string" ? resolvedSearchParams.token : "";

  if (!token) {
    return (
      <main className="stack">
        <section className="card stack">
          <h1 className="title">無効なリンクです</h1>
          <p className="subtle">URLに token が含まれていません。作成者から受け取ったリンクを開き直してください。</p>
          <Link className="button secondary" href="/">
            トップへ戻る
          </Link>
        </section>
      </main>
    );
  }

  try {
    const quiz = await fetchQuizByPublicId(quizPublicId);

    if (!quiz) {
      return (
        <main className="stack">
          <section className="card stack">
            <h1 className="title">診断が見つかりません</h1>
            <p className="subtle">公開IDが誤っているか、診断が削除されている可能性があります。</p>
            <Link className="button secondary" href="/">
              トップへ戻る
            </Link>
          </section>
        </main>
      );
    }

    if (!quiz.questions.length) {
      return (
        <main className="stack">
          <section className="card stack">
            <h1 className="title">この診断はまだ回答できません</h1>
            <p className="subtle">設問が設定されていないため回答を開始できません。</p>
            <Link className="button secondary" href="/">
              トップへ戻る
            </Link>
          </section>
        </main>
      );
    }

    return <QuizRunner quiz={quiz} quizPublicId={quizPublicId} token={token} />;
  } catch (error) {
    return (
      <main className="stack">
        <section className="card stack">
          <h1 className="title">読み込みに失敗しました</h1>
          <p className="error">{error instanceof Error ? error.message : "unknown error"}</p>
          <Link className="button secondary" href="/">
            トップへ戻る
          </Link>
        </section>
      </main>
    );
  }
}
