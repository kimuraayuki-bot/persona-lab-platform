"use client";

import { useState } from "react";
import { submitQuizReport } from "@/lib/supabase";

const REASONS = [
  { value: "illegal", label: "違法・犯罪" },
  { value: "sexual", label: "性的コンテンツ" },
  { value: "violent", label: "暴力・残虐" },
  { value: "harassment", label: "嫌がらせ・差別" },
  { value: "copyright", label: "著作権・権利侵害" },
  { value: "spam", label: "スパム・釣り" },
  { value: "other", label: "その他" }
];

export default function ReportForm({ quizPublicId, source, pageURL = "", returnPath = "/" }) {
  const [reason, setReason] = useState("illegal");
  const [details, setDetails] = useState("");
  const [reporterEmail, setReporterEmail] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  const onSubmit = async (event) => {
    event.preventDefault();
    if (!quizPublicId) {
      setError("対象の診断IDが指定されていません。");
      return;
    }

    setIsSubmitting(true);
    setError("");

    try {
      await submitQuizReport({
        quiz_public_id: quizPublicId,
        source,
        reason,
        details,
        reporter_email: reporterEmail || undefined,
        page_url: pageURL || undefined
      });
      setSuccess(true);
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : "通報の送信に失敗しました。");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (success) {
    return (
      <section className="card stack">
        <span className="badge">Report</span>
        <h1 className="title">通報を受け付けました</h1>
        <p className="subtle">
          内容を確認し、必要に応じて非表示化や掲載停止を行います。追加情報が必要な場合のみご連絡します。
        </p>
        <div className="row wrap">
          <a className="button primary" href={returnPath}>
            元のページへ戻る
          </a>
          <a className="button secondary" href="/contact">
            追加で問い合わせる
          </a>
        </div>
      </section>
    );
  }

  return (
    <form className="card stack report-form" onSubmit={onSubmit}>
      <span className="badge">Report</span>
      <h1 className="title">診断を通報する</h1>
      <p className="subtle">
        違法、不適切、権利侵害などの問題がある場合は理由を選んで送信してください。
      </p>

      <label className="field">
        <span>対象の診断ID</span>
        <input type="text" value={quizPublicId} readOnly />
      </label>

      <label className="field">
        <span>問題の種類</span>
        <select value={reason} onChange={(event) => setReason(event.target.value)}>
          {REASONS.map((item) => (
            <option key={item.value} value={item.value}>
              {item.label}
            </option>
          ))}
        </select>
      </label>

      <label className="field">
        <span>補足情報</span>
        <textarea
          rows={5}
          value={details}
          onChange={(event) => setDetails(event.target.value)}
          placeholder="問題の箇所、権利者名、判断理由などがあれば記載してください。"
        />
      </label>

      <label className="field">
        <span>連絡先メールアドレス</span>
        <input
          type="email"
          value={reporterEmail}
          onChange={(event) => setReporterEmail(event.target.value)}
          placeholder="任意。返信が必要な場合に使用します。"
        />
      </label>

      {pageURL ? (
        <label className="field">
          <span>報告対象ページ</span>
          <input type="text" value={pageURL} readOnly />
        </label>
      ) : null}

      {error ? <div className="error">{error}</div> : null}

      <div className="row wrap">
        <button className="button primary" type="submit" disabled={isSubmitting}>
          {isSubmitting ? "送信中..." : "通報を送信"}
        </button>
        <a className="button secondary" href={returnPath}>
          戻る
        </a>
      </div>
    </form>
  );
}
