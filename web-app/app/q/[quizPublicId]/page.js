import Link from "next/link";
import QuizRunner from "./quiz-runner";
import { fetchQuizByPublicId } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function QuizAnswerPage({ params, searchParams }) {
  // Next.js 16 treats route params/searchParams as async request APIs.
  const resolvedParams = await params;
  const resolvedSearchParams = await searchParams;
  const quizPublicId = resolvedParams?.quizPublicId;
  const tokenFromObject = typeof resolvedSearchParams?.token === "string" ? resolvedSearchParams.token : "";
  const tokenFromURLSearchParams =
    typeof resolvedSearchParams?.get === "function" ? resolvedSearchParams.get("token") ?? "" : "";
  const token = tokenFromObject || tokenFromURLSearchParams;

  try {
    const quiz = await fetchQuizByPublicId(quizPublicId, token);

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

    return <QuizRunner quiz={quiz} quizPublicId={quizPublicId} token={token || null} />;
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown error";
    const invalidLinkMessage = message === "token required" || message === "invalid token" || message === "token expired";

    return (
      <main className="stack">
        <section className="card stack">
          <h1 className="title">{invalidLinkMessage ? "この診断は共有リンクが必要です" : "読み込みに失敗しました"}</h1>
          <p className={invalidLinkMessage ? "subtle" : "error"}>
            {invalidLinkMessage
              ? "作成者から受け取ったURLを開き直してください。ランキング公開されている診断だけが token なしで回答できます。"
              : message}
          </p>
          <Link className="button secondary" href="/">
            トップへ戻る
          </Link>
        </section>
      </main>
    );
  }
}
