import Foundation

public extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        var current = components.queryItems ?? []
        current.append(contentsOf: queryItems)
        components.queryItems = current
        return components.url ?? self
    }
}
