"use client";

import { useMemo, useState } from "react";
import AdSenseSlot from "@/components/AdSenseSlot";
import { submitResponse } from "@/lib/supabase";

const resultAdSlot = process.env.NEXT_PUBLIC_ADSENSE_RESULT_SLOT_ID ?? "";

function axisValue(axisKey, scores) {
  switch (axisKey) {
    case "ei":
      return scores?.ei ?? 0;
    case "sn":
      return scores?.sn ?? 0;
    case "tf":
      return scores?.tf ?? 0;
    case "jp":
      return scores?.jp ?? 0;
    default:
      return 0;
  }
}

function bubbleSize(index) {
  return [42, 36, 30, 24, 30, 36, 42][index] ?? 30;
}

function selectionLabel(index) {
  switch (index) {
    case 0:
      return "とてもそう思う";
    case 1:
      return "ややそう思う";
    case 2:
      return "少しそう思う";
    case 3:
      return "どちらでもない";
    case 4:
      return "少しそう思わない";
    case 5:
      return "ややそう思わない";
    case 6:
      return "とてもそう思わない";
    default:
      return "選択済み";
  }
}

function normalizeEdgeLabel(text, fallback) {
  const trimmed = (text ?? "").trim();
  if (!trimmed || trimmed === "どちらでもない") {
    return fallback;
  }

  const prefixes = ["とても", "やや", "少し"];
  for (const prefix of prefixes) {
    if (trimmed.startsWith(prefix) && trimmed.length > prefix.length) {
      return trimmed.slice(prefix.length);
    }
  }

  return trimmed;
}

function isScaleQuestion(question) {
  return Array.isArray(question?.choices) && question.choices.length === 7;
}

export default function QuizRunner({ quiz, quizPublicId, token }) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [answers, setAnswers] = useState({});
  const [result, setResult] = useState(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const currentQuestion = quiz.questions[currentIndex];
  const progress = ((currentIndex + 1) / Math.max(quiz.questions.length, 1)) * 100;

  const resultCode = useMemo(() => {
    if (!result) {
      return "";
    }
    return (result.result_code || result.mbti_type || "").toUpperCase();
  }, [result]);

  const matchedProfile = useMemo(() => {
    if (!resultCode) {
      return null;
    }

    return quiz.resultProfiles?.find((profile) => profile.resultCode === resultCode) ?? null;
  }, [quiz.resultProfiles, resultCode]);

  const roleName = result?.role_name || matchedProfile?.roleName || (resultCode ? `${resultCode}タイプ` : "");
  const resultSummary = result?.summary || matchedProfile?.summary || "あなたらしい個性が出た結果です。";
  const resultDetail = result?.detail || matchedProfile?.detail || "";

  const canMoveNext = Boolean(currentQuestion && answers[currentQuestion.id]);

  const sortedChoices = useMemo(() => {
    if (!currentQuestion?.choices) {
      return [];
    }
    return [...currentQuestion.choices].sort((a, b) => a.orderIndex - b.orderIndex);
  }, [currentQuestion]);

  const leftLabel = useMemo(() => {
    if (!isScaleQuestion(currentQuestion)) {
      return "";
    }
    return normalizeEdgeLabel(sortedChoices[0]?.body, "そう思う");
  }, [currentQuestion, sortedChoices]);

  const rightLabel = useMemo(() => {
    if (!isScaleQuestion(currentQuestion)) {
      return "";
    }
    return normalizeEdgeLabel(sortedChoices[sortedChoices.length - 1]?.body, "そう思わない");
  }, [currentQuestion, sortedChoices]);

  const selectedScaleIndex = useMemo(() => {
    if (!currentQuestion || !isScaleQuestion(currentQuestion)) {
      return null;
    }

    const choiceID = answers[currentQuestion.id];
    if (!choiceID) {
      return null;
    }

    const index = sortedChoices.findIndex((choice) => choice.id === choiceID);
    return index >= 0 ? index : null;
  }, [answers, currentQuestion, sortedChoices]);

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
    const displayName = roleName ? `${resultCode}（${roleName}）` : resultCode;
    const text = `私の診断結果は ${displayName} でした。あなたも回答してみてください。\n${shareUrl}`;

    try {
      await navigator.clipboard.writeText(text);
      setNotice("共有文をコピーしました。");
    } catch {
      setError("コピーに失敗しました。");
    }
  };

  const onShare = async () => {
    const shareUrl = `${window.location.origin}/q/${quizPublicId}?token=${encodeURIComponent(token)}`;
    const displayName = roleName ? `${resultCode}（${roleName}）` : resultCode;
    const text = `私の診断結果は ${displayName} でした。あなたも回答してみてください。`;

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
          <h1 className="result-type">{resultCode}</h1>
          {roleName ? <h2 className="title" style={{ fontSize: "1.1rem" }}>{roleName}</h2> : null}
          <p className="subtle">{resultSummary}</p>
          {resultDetail ? <p className="subtle">{resultDetail}</p> : null}

          <div className="axes">
            {(quiz.axisDefinitions ?? []).filter((axis) => axis.isEnabled !== false).map((axis) => (
              <div className="axis" key={axis.axisKey}>
                <div className="k">{`${axis.positiveCode}/${axis.negativeCode}`}</div>
                <div className="v">{axisValue(axis.axisKey, result.axis_scores)}</div>
              </div>
            ))}
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

        <AdSenseSlot className="card" slot={resultAdSlot} />
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

        {isScaleQuestion(currentQuestion) ? (
          <div className="scale-wrap">
            <div className="scale-labels">
              <span>{leftLabel}</span>
              <span>{rightLabel}</span>
            </div>

            <div className="scale-points">
              {sortedChoices.map((choice, index) => {
                const selected = answers[currentQuestion.id] === choice.id;
                return (
                  <button
                    key={choice.id}
                    type="button"
                    className={`scale-point${selected ? " active" : ""}`}
                    style={{ width: bubbleSize(index), height: bubbleSize(index) }}
                    onClick={() => onChoice(currentQuestion.id, choice.id)}
                    aria-label={selectionLabel(index)}
                  />
                );
              })}
            </div>

            <p className="subtle scale-selection">
              {selectedScaleIndex == null ? "丸をタップして選択" : selectionLabel(selectedScaleIndex)}
            </p>
          </div>
        ) : (
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
        )}

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
