import Foundation
import PersonaLabCore

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

    static func load(env: [String: String] = ProcessInfo.processInfo.environment) -> RuntimeConfig? {
        let useMock = (env["USE_MOCK_API"] ?? "").lowercased()
        if useMock == "1" || useMock == "true" {
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
}
