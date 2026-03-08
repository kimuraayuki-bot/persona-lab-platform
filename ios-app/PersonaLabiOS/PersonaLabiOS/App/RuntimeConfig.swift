import Foundation

struct RuntimeConfig {
    let projectRef: String
    let anonKey: String
    let appDomain: URL

    // Development defaults to reduce first-run setup friction.
    static let defaultProjectRef = "tdctpfxrormusqduvyuq"
    static let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkY3RwZnhyb3JtdXNxZHV2eXVxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODc0NzEsImV4cCI6MjA4ODQ2MzQ3MX0.EsGEm_mTJboR3s8SgRn1ApL5wcKZihM0yNTdeEQZRUM"

    var appConfig: AppConfig {
        AppConfig(projectRef: projectRef, anonKey: anonKey, appDomain: appDomain)
    }

    static func shouldUseMockAPI(env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        boolFlag("USE_MOCK_API", env: env)
    }

    static func shouldSkipLoginForDev(env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        boolFlag("SKIP_LOGIN_FOR_DEV", env: env)
            || boolFlag("BYPASS_LOGIN", env: env)
            || boolFlag("DISABLE_AUTH_FOR_DEV", env: env)
    }

    static func load(env: [String: String] = ProcessInfo.processInfo.environment) -> RuntimeConfig? {
        if shouldUseMockAPI(env: env) {
            return nil
        }

        let projectRef = env["SUPABASE_PROJECT_REF"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let anonKey = env["SUPABASE_ANON_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedProjectRef = (projectRef?.isEmpty == false) ? projectRef! : defaultProjectRef
        let resolvedAnonKey = (anonKey?.isEmpty == false) ? anonKey! : defaultAnonKey

        let appDomainString = env["APP_DOMAIN"] ?? "https://example.com"
        guard let appDomain = URL(string: appDomainString) else {
            return nil
        }

        return RuntimeConfig(projectRef: resolvedProjectRef, anonKey: resolvedAnonKey, appDomain: appDomain)
    }

    private static func boolFlag(_ key: String, env: [String: String]) -> Bool {
        let raw = (env[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
    }
}
