import Foundation

/// Protocol defining the authentication service interface
/// Allows for easy testing and dependency injection by providing a contract
/// that concrete implementations must follow
protocol AuthServiceProtocol {
    /// Attempts to authenticate a user with the provided credentials
    /// - Parameters:
    ///   - username: The user's username or email
    ///   - password: The user's password
    /// - Returns: An AuthToken containing the authentication token and expiration
    /// - Throws: LoginError if authentication fails
    func login(username: String, password: String) async throws -> AuthToken

    /// Retrieves a previously saved authentication token
    /// - Returns: A valid AuthToken if one exists and hasn't expired, nil otherwise
    func getSavedToken() -> AuthToken?

    /// Saves the authentication token for "Remember Me" functionality
    /// - Parameter token: The AuthToken to save for future use
    func saveToken(_ token: AuthToken)

    /// Removes the saved authentication token
    func clearSavedToken()
}

/// Represents an authentication token with expiration information
/// Contains the token string and its expiration date for validation
struct AuthToken {
    /// The actual authentication token string
    let token: String

    /// When this token expires and should no longer be considered valid
    let expirationDate: Date
}

/// Concrete implementation of the authentication service
/// Provides mock authentication for demonstration purposes
/// In a real app, this would make network requests to a backend service
class AuthService: AuthServiceProtocol {
    // MARK: - Constants

    /// UserDefaults key for storing the authentication token
    private let tokenKey = "auth_token"

    /// UserDefaults key for storing the token expiration date
    private let tokenExpirationKey = "auth_token_expiration"

    // MARK: - Authentication Methods

    /// Performs user authentication with the provided credentials
    /// This is a mock implementation that simulates a network request
    /// - Parameters:
    ///   - username: The user's username (accepts "user" for demo)
    ///   - password: The user's password (accepts "password" for demo)
    /// - Returns: A valid AuthToken if credentials are correct
    /// - Throws: LoginError.invalidCredentials if credentials are wrong
    func login(username: String, password: String) async throws -> AuthToken {
        // Simulate network delay that would occur in a real authentication request
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        // Mock authentication logic - in production this would validate against a server
        if username == "user" && password == "password" {
            // Create a token that expires in 1 hour
            let token = AuthToken(
                token: UUID().uuidString, // Generate a unique token
                expirationDate: Date().addingTimeInterval(3600) // 1 hour from now
            )
            return token
        } else {
            // Authentication failed - throw appropriate error
            throw LoginError.invalidCredentials
        }
    }

    // MARK: - Token Persistence Methods

    /// Saves the authentication token to UserDefaults for "Remember Me" functionality
    /// Stores both the token string and its expiration date
    /// - Parameter token: The AuthToken to save for future use
    func saveToken(_ token: AuthToken) {
        UserDefaults.standard.set(token.token, forKey: tokenKey)
        UserDefaults.standard.set(token.expirationDate, forKey: tokenExpirationKey)
    }

    /// Retrieves a previously saved authentication token from UserDefaults
    /// Validates that the token exists and hasn't expired before returning it
    /// - Returns: A valid AuthToken if one exists and hasn't expired, nil otherwise
    func getSavedToken() -> AuthToken? {
        // Attempt to retrieve the saved token and expiration date
        guard let tokenString = UserDefaults.standard.string(forKey: tokenKey),
              let expirationDate = UserDefaults.standard.object(forKey: tokenExpirationKey) as? Date,
              expirationDate > Date() else {
            // Token doesn't exist, is malformed, or has expired
            return nil
        }

        // Return the valid, non-expired token
        return AuthToken(token: tokenString, expirationDate: expirationDate)
    }

    /// Removes the saved authentication token from UserDefaults
    /// Called during logout or when the user chooses not to be remembered
    func clearSavedToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpirationKey)
    }
}