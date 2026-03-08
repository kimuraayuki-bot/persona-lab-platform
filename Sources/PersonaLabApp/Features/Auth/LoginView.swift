import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var state: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 40)

                Text("Persona Lab")
                    .font(.largeTitle.bold())
                Text("診断を作成してリンク共有")
                    .foregroundStyle(.secondary)

                Button("Appleでログイン（準備中）") {
                    state.loginWithApple()
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 10) {
                    TextField("メールアドレス", text: $email)
                        .padding(12)
                        .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    SecureField("パスワード", text: $password)
                        .padding(12)
                        .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    Toggle("新規登録として使う", isOn: $isSignUpMode)
                        .font(.footnote)

                    Button(isSignUpMode ? "メールで登録してログイン" : "メールでログイン") {
                        Task {
                            await state.loginWithEmail(email: email, password: password, isSignUp: isSignUpMode)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.isAuthLoading)

                    if state.isAuthLoading {
                        ProgressView("認証中...")
                            .font(.footnote)
                    }

                    if let authNoticeMessage = state.authNoticeMessage {
                        Text(authNoticeMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                Spacer(minLength: 20)
            }
            .padding()
        }
    }
}
