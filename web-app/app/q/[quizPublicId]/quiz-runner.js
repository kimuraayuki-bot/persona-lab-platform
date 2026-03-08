"use client";

import { useMemo, useState } from "react";
import { submitResponse } from "@/lib/supabase";

const MBTI_SUMMARY = {
  INTJ: "戦略志向で計画を立てて前進するタイプ",
  INTP: "分析力が高く概念を深掘りするタイプ",
  ENTJ: "意思決定が速く目標達成を牽引するタイプ",
  ENTP: "発想が豊かで変化を楽しむタイプ",
  INFJ: "洞察力と共感力で周囲を支えるタイプ",
  INFP: "価値観を大切にし創造性を発揮するタイプ",
  ENFJ: "対人理解に優れ人を巻き込むタイプ",
  ENFP: "好奇心旺盛で可能性を広げるタイプ",
  ISTJ: "誠実で着実に物事を完遂するタイプ",
  ISFJ: "献身的で細やかな配慮が得意なタイプ",
  ESTJ: "現実的で運営力に優れるタイプ",
  ESFJ: "協調性が高く場を整えるタイプ",
  ISTP: "冷静に状況を捉え実践で解決するタイプ",
  ISFP: "感性豊かで柔軟に周囲と関わるタイプ",
  ESTP: "行動力が高く機会を掴むタイプ",
  ESFP: "明るく社交的で空気を盛り上げるタイプ"
};

export default function QuizRunner({ quiz, quizPublicId, token }) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [answers, setAnswers] = useState({});
  const [result, setResult] = useState(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const currentQuestion = quiz.questions[currentIndex];
  const progress = ((currentIndex + 1) / Math.max(quiz.questions.length, 1)) * 100;

  const resultSummary = useMemo(() => {
    if (!result) {
      return "";
    }
    return MBTI_SUMMARY[result.mbti_type] ?? "あなたらしい個性が出た結果です。";
  }, [result]);

  const canMoveNext = Boolean(currentQuestion && answers[currentQuestion.id]);

  const onChoice = (questionId, choiceId) => {
    setAnswers((prev) => ({ ...prev, [questionId]: choiceId }));
    setError("");
  };

  const onNext = async () => {
    if (!currentQuestion || !canMoveNext || isSubmitting) {
      return;
    }

    if (currentIndex < quiz.questions.length - 1) {
      setCurrentIndex((prev) => prev + 1);
      return;
    }

    const payloadAnswers = quiz.questions.map((q) => ({
      question_id: q.id,
      choice_id: answers[q.id]
    }));

    setIsSubmitting(true);
    setError("");

    try {
      const submitted = await submitResponse({
        quiz_public_id: quizPublicId,
        token,
        answers: payloadAnswers
      });
      setResult(submitted);
      setNotice("回答を送信しました。結果を表示しています。");
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : "送信に失敗しました");
    } finally {
      setIsSubmitting(false);
    }
  };

  const onBack = () => {
    if (currentIndex > 0) {
      setCurrentIndex((prev) => prev - 1);
    }
  };

  const onCopy = async () => {
    const shareUrl = `${window.location.origin}/q/${quizPublicId}?token=${encodeURIComponent(token)}`;
    const text = `私の診断結果は ${result.mbti_type} でした。あなたも回答してみてください。\n${shareUrl}`;

    try {
      await navigator.clipboard.writeText(text);
      setNotice("共有文をコピーしました。");
    } catch {
      setError("コピーに失敗しました。");
    }
  };

  const onShare = async () => {
    const shareUrl = `${window.location.origin}/q/${quizPublicId}?token=${encodeURIComponent(token)}`;
    const text = `私の診断結果は ${result.mbti_type} でした。あなたも回答してみてください。`;

    if (!navigator.share) {
      setError("このブラウザでは共有APIが使えません。コピーを使ってください。");
      return;
    }

    try {
      await navigator.share({
        title: `${quiz.title} の結果`,
        text,
        url: shareUrl
      });
    } catch {
      // no-op: user cancelled share
    }
  };

  if (result) {
    return (
      <main className="stack">
        <section className="card stack">
          <span className="badge">診断結果</span>
          <h1 className="result-type">{result.mbti_type}</h1>
          <p className="subtle">{resultSummary}</p>

          <div className="axes">
            <div className="axis">
              <div className="k">EI</div>
              <div className="v">{result.axis_scores?.ei ?? 0}</div>
            </div>
            <div className="axis">
              <div className="k">SN</div>
              <div className="v">{result.axis_scores?.sn ?? 0}</div>
            </div>
            <div className="axis">
              <div className="k">TF</div>
              <div className="v">{result.axis_scores?.tf ?? 0}</div>
            </div>
            <div className="axis">
              <div className="k">JP</div>
              <div className="v">{result.axis_scores?.jp ?? 0}</div>
            </div>
          </div>

          <div className="row wrap">
            <button className="button primary" onClick={onShare}>
              共有する
            </button>
            <button className="button secondary" onClick={onCopy}>
              共有文をコピー
            </button>
            <a className="button ghost" href={`myapp://quiz/${quizPublicId}?token=${encodeURIComponent(token)}`}>
              アプリで開く
            </a>
          </div>

          {notice ? <div className="success">{notice}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </section>
      </main>
    );
  }

  return (
    <main className="stack">
      <section className="card stack">
        <span className="badge">{currentIndex + 1} / {quiz.questions.length}</span>
        <h1 className="title">{quiz.title}</h1>
        {quiz.description ? <p className="subtle">{quiz.description}</p> : null}

        <div className="progress">
          <span style={{ width: `${progress}%` }} />
        </div>
      </section>

      <section className="card stack">
        <h2 className="title" style={{ fontSize: "1.2rem" }}>
          {currentQuestion.prompt}
        </h2>

        <div className="stack">
          {currentQuestion.choices.map((choice) => {
            const selected = answers[currentQuestion.id] === choice.id;
            return (
              <button
                key={choice.id}
                type="button"
                className={`choice${selected ? " active" : ""}`}
                onClick={() => onChoice(currentQuestion.id, choice.id)}
              >
                {choice.body}
              </button>
            );
          })}
        </div>

        <div className="row wrap">
          <button className="button secondary" onClick={onBack} disabled={currentIndex === 0 || isSubmitting}>
            戻る
          </button>
          <button className="button primary" onClick={onNext} disabled={!canMoveNext || isSubmitting}>
            {isSubmitting ? "送信中..." : currentIndex === quiz.questions.length - 1 ? "結果を見る" : "次へ"}
          </button>
        </div>

        {!canMoveNext ? <p className="subtle">次へ進むには選択肢を1つ選んでください。</p> : null}
        {notice ? <div className="success">{notice}</div> : null}
        {error ? <div className="error">{error}</div> : null}
      </section>
    </main>
  );
}
