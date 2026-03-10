import ReportForm from "@/components/ReportForm";

export const metadata = {
  title: "Report | Persona Lab",
  description: "Persona Lab Web の診断通報フォーム"
};

export default async function ReportPage({ searchParams }) {
  const resolvedSearchParams = await searchParams;
  const quizPublicId =
    typeof resolvedSearchParams?.quiz_public_id === "string" ? resolvedSearchParams.quiz_public_id : "";
  const source =
    typeof resolvedSearchParams?.source === "string" ? resolvedSearchParams.source : "web_quiz";
  const pageURL =
    typeof resolvedSearchParams?.page_url === "string" ? resolvedSearchParams.page_url : "";
  const returnPath =
    typeof resolvedSearchParams?.return_to === "string" ? resolvedSearchParams.return_to : "/";

  return (
    <main className="stack">
      <ReportForm
        pageURL={pageURL}
        quizPublicId={quizPublicId}
        returnPath={returnPath}
        source={source}
      />
    </main>
  );
}
