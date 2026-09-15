import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    private func respond(to action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            if #available(iOS 26.5, *) {
                completionHandler(.openParentalControlsApp)
            } else {
                // iOS did not expose an API for a shield extension to launch
                // its parent app before 26.5. Keep the shield in place.
                completionHandler(.defer)
            }
        case .secondaryButtonPressed:
            completionHandler(.close)
        default:
            completionHandler(.defer)
        }
    }
}
