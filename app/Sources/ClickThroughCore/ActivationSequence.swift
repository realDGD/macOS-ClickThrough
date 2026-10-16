public enum ActivationSequence {
    /// The application request is permitted only after the window setter succeeds.
    @discardableResult
    public static func run(window: () -> Bool, application: () -> Void) -> Bool {
        guard window() else { return false }
        application()
        return true
    }
}
