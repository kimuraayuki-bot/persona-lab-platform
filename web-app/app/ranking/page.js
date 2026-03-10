import { fetchQuizRanking } from "@/lib/supabase";

export const metadata = {
  title: "Ranking | Persona Lab",
  description: "公開診断の回答数ランキング"
};

export const dynamic = "force-dynamic";

function formatUpdatedAt(value) {
  if (!value) {
    return "更新日時不明";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "更新日時不明";
  }

  return new Intl.DateTimeFormat("ja-JP", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(date);
}

export default async function RankingPage() {
  try {
    const ranking = await fetchQuizRanking(20);

    return (
      <main className="stack">
        <section className="card legal-page">
          <span className="badge">Ranking</span>
          <h1 className="title">回答数ランキング</h1>
          <p className="subtle">
            公開診断のうち、回答数が多いものを上位から表示しています。各カードでは回答数と上位タイプ分布を確認できます。
          </p>
        </section>

        {ranking.length === 0 ? (
          <section className="card legal-page">
            <h2>まだ表示できるランキングがありません</h2>
            <p className="subtle">
              公開診断への回答が蓄積されると、このページにランキングが表示されます。
            </p>
          </section>
        ) : (
          <section className="ranking-list">
            {ranking.map((entry) => (
              <article className="card ranking-card" key={entry.quizId}>
                <div className="ranking-header">
                  <div className="row" style={{ alignItems: "flex-start" }}>
                    <span className="ranking-rank">#{entry.rank}</span>
                    <div className="stack compact">
                      <h2 className="title">{entry.quiz.title}</h2>
                      {entry.quiz.description ? <p className="subtle">{entry.quiz.description}</p> : null}
                    </div>
                  </div>
                  <div className="ranking-meta">
                    <span className="stat-pill">回答 {entry.totalResponses} 件</span>
                    <span className="stat-pill">{formatUpdatedAt(entry.updatedAt)}</span>
                  </div>
                </div>

                <div className="result-breakdown">
                  {entry.topResults.length === 0 ? (
                    <p className="subtle">まだタイプ別集計はありません。</p>
                  ) : (
                    entry.topResults.map((result) => {
                      const rate = entry.totalResponses > 0
                        ? Math.round((result.responseCount / entry.totalResponses) * 100)
                        : 0;

                      return (
                        <div className="result-row" key={`${entry.quizId}-${result.resultCode}`}>
                          <span className="result-code">{result.resultCode}</span>
                          <div className="result-meter" aria-hidden="true">
                            <span style={{ width: `${Math.max(rate, 6)}%` }} />
                          </div>
                          <span className="subtle">{result.responseCount} 件 / {rate}% </span>
                        </div>
                      );
                    })
                  )}
                </div>
              </article>
            ))}
          </section>
        )}
      </main>
    );
  } catch (error) {
    return (
      <main className="stack">
        <section className="card legal-page">
          <span className="badge">Ranking</span>
          <h1 className="title">回答数ランキング</h1>
          <p className="error">
            {error instanceof Error ? error.message : "ランキングの読み込みに失敗しました。"}
          </p>
        </section>
      </main>
    );
  }
}
