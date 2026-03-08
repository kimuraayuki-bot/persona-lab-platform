import SwiftUI
import PersonaLabCore

struct QuizListView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List(state.quizzes) { quiz in
                NavigationLink(quiz.title) {
                    QuizTakingView(quiz: quiz)
                }
                .accessibilityIdentifier("quiz_\(quiz.publicID)")
            }
            .navigationTitle("診断一覧")
            .toolbar {
                ToolbarItem {
                    Button("新規作成") { showingEditor = true }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack {
                    QuizEditorView { newQuiz in
                        state.upsertQuiz(newQuiz)
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { state.activeQuiz != nil },
                set: { if !$0 { state.activeQuiz = nil } }
            )) {
                if let quiz = state.activeQuiz {
                    QuizTakingView(quiz: quiz)
                }
            }
        }
    }
}
