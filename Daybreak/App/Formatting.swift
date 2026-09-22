import Foundation

/// "1 app" / "5 apps". The count includes categories and websites; "apps" keeps the copy plain.
nonisolated func appsPhrase(_ count: Int) -> String {
    count == 1 ? "1 app" : "\(count) apps"
}
