import Foundation

/// Represents the different states that the login process can be in
/// Used to manage UI state and provide appropriate user feedback
enum LoginState: Equatable {
    /// Initial state - no login attempt has been made
    case idle

    /// Login request is in progress - show loading indicator
    case loading

    /// Login was successful - navigate to main app or show success message
    case success

    /// Login failed with a specific error message - display error to user
    case error(String)

    /// Account is locked due to too many failed attempts - show lockout message
    case lockedOut
}

/// Defines specific login-related errors with user-friendly messages
/// Conforms to LocalizedError to provide appropriate error descriptions
enum LoginError: Error, LocalizedError {
    /// User provided incorrect username or password
    case invalidCredentials

    /// Network request failed due to connectivity issues
    case networkError

    /// Account is locked due to too many failed login attempts
    case lockedOut

    /// Device is offline and cannot make network requests
    case offline

    /// Provides user-friendly error messages for each error case
    /// These messages are displayed directly to the user
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkError:
            return "Network error occurred"
        case .lockedOut:
            return "Account locked due to too many failed attempts"
        case .offline:
            return "No internet connection"
        }
    }
}