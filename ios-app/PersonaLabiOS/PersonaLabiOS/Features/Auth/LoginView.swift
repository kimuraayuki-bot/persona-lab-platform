import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var state: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !state.isAuthLoading
    }

    private var modeDescription: String {
        if isSignUpMode {
            return "初回は仮登録され、確認メールのリンクを開くとログインできます。"
        }
        return "登録済みメールアドレスでログインします。"
    }

    var body: some View {
        ZStack {
            PopBackdrop().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Spacer(minLength: 30)

                    VStack(spacing: 8) {
                        Text("Persona Lab")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(PopTheme.textPrimary)
                        Text("診断を作成してリンク共有")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("メール認証")
                            .font(.headline)
                            .foregroundStyle(PopTheme.textPrimary)

                        TextField("メールアドレス", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .submitLabel(.next)
                            .padding(12)
                            .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        SecureField("パスワード", text: $password)
                            .textContentType(isSignUpMode ? .newPassword : .password)
                            .submitLabel(.go)
                            .padding(12)
                            .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onSubmit {
                                guard canSubmit else { return }
                                Task {
                                    await state.loginWithEmail(email: email, password: password, isSignUp: isSignUpMode)
                                }
                            }

                        Toggle("新規登録として使う", isOn: $isSignUpMode)
                            .font(.footnote)

                        Text(modeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(isSignUpMode ? "メールで登録" : "メールでログイン") {
                            Task {
                                await state.loginWithEmail(email: email, password: password, isSignUp: isSignUpMode)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PopTheme.accent)
                        .disabled(!canSubmit)

                        if state.isAuthLoading {
                            ProgressView("認証中...")
                                .font(.footnote)
                        }

                        if let authNoticeMessage = state.authNoticeMessage {
                            Text(authNoticeMessage)
                                .font(.footnote)
                                .foregroundStyle(PopTheme.accentAlt)
                        }
                    }
                    .popCard()

                    Button("Appleでログイン（準備中）") {
                        state.loginWithApple()
                    }
                    .buttonStyle(.bordered)

                    Text("ログインできない場合は、メール確認・入力ミス・SMTP設定を確認してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(16)
            }
        }
    }
}
