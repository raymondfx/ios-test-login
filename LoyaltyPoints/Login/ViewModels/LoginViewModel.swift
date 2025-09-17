import Foundation
import Combine

/// ViewModel for the login screen following MVVM architecture pattern
/// Manages all login-related business logic, validation, and state management
/// Conforms to ObservableObject to work seamlessly with SwiftUI
class LoginViewModel: ObservableObject {
    // MARK: - Published Properties

    /// User's entered username - automatically updates UI when changed
    @Published var username = ""

    /// User's entered password - automatically updates UI when changed
    @Published var password = ""

    /// Whether the user wants their login to be remembered
    @Published var rememberMe = false

    /// Current state of the login process - drives UI updates
    @Published var state: LoginState = .idle

    /// Whether the login form is valid and ready for submission
    @Published var isFormValid = false

    // MARK: - Dependencies

    /// Service responsible for handling authentication requests
    private let authService: AuthServiceProtocol

    /// Monitor for tracking network connectivity status
    private let networkMonitor: NetworkMonitor

    /// Set to store Combine subscriptions and prevent memory leaks
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Security Constants

    /// Maximum number of failed login attempts before account lockout
    private let maxFailureAttempts = 3

    /// Duration of account lockout in seconds (5 minutes)
    private let lockoutDuration: TimeInterval = 300

    /// UserDefaults key for storing the number of failed login attempts
    private let failureCountKey = "login_failure_count"

    /// UserDefaults key for storing the lockout expiration time
    private let lockoutTimeKey = "lockout_time"

    // MARK: - Computed Properties

    /// Current number of failed login attempts stored in UserDefaults
    var failureCount: Int {
        get { UserDefaults.standard.integer(forKey: failureCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: failureCountKey) }
    }

    /// Time when the current lockout period expires, if any
    var lockoutTime: Date? {
        get { UserDefaults.standard.object(forKey: lockoutTimeKey) as? Date }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: lockoutTimeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lockoutTimeKey)
            }
        }
    }

    /// Whether the account is currently locked out due to too many failed attempts
    var isLockedOut: Bool {
        guard let lockoutTime = lockoutTime else { return false }
        return Date() < lockoutTime
    }

    // MARK: - Initialization

    /// Initializes the LoginViewModel with required dependencies
    /// Sets up form validation and checks for existing saved tokens
    /// - Parameters:
    ///   - authService: Service for handling authentication (defaults to AuthService)
    ///   - networkMonitor: Monitor for network connectivity (defaults to NetworkMonitor)
    init(authService: AuthServiceProtocol = AuthService(), networkMonitor: NetworkMonitor = NetworkMonitor()) {
        self.authService = authService
        self.networkMonitor = networkMonitor

        setupValidation()
        checkForSavedToken()
    }

    // MARK: - Private Setup Methods

    /// Sets up reactive form validation using Combine
    /// Automatically updates isFormValid when username or password changes
    private func setupValidation() {
        // Combine the username and password publishers to determine form validity
        Publishers.CombineLatest($username, $password)
            .map { username, password in
                // Form is valid if both fields have non-empty content (after trimming whitespace)
                !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .assign(to: \.isFormValid, on: self)
            .store(in: &cancellables)
    }

    /// Checks if there's a saved authentication token from a previous "Remember Me" login
    /// If a valid token exists, automatically sets the state to success
    func checkForSavedToken() {
        if let savedToken = authService.getSavedToken() {
            state = .success
        }
    }

    // MARK: - Public Methods

    /// Attempts to log in the user with the provided credentials
    /// Performs various validation checks before making the authentication request
    func login() {
        // Ensure the form is valid before proceeding
        guard isFormValid else { return }

        // Check if the account is currently locked out
        guard !isLockedOut else {
            state = .lockedOut
            return
        }

        // Verify network connectivity before attempting login
        guard networkMonitor.isConnected else {
            state = .error("No internet connection")
            return
        }

        // Set loading state to show progress indicator
        state = .loading

        // Perform the login request asynchronously
        Task {
            do {
                // Attempt authentication with the provided credentials
                let token = try await authService.login(username: username, password: password)

                // Handle successful authentication on the main thread
                await MainActor.run {
                    // Save the token if "Remember Me" is enabled
                    if rememberMe {
                        authService.saveToken(token)
                    }

                    // Reset failure count and lockout status on successful login
                    resetFailureCount()

                    // Update state to success
                    state = .success
                }
            } catch {
                // Handle login failure on the main thread
                await MainActor.run {
                    handleLoginFailure(error)
                }
            }
        }
    }

    /// Logs out the current user and resets the login form
    /// Clears saved tokens and resets all form fields to their initial state
    func logout() {
        // Clear any saved authentication token
        authService.clearSavedToken()

        // Reset form fields to their initial state
        username = ""
        password = ""
        rememberMe = false

        // Reset state to idle
        state = .idle
    }

    // MARK: - Private Helper Methods

    /// Handles login failure by updating failure count and determining appropriate action
    /// Either shows an error message or locks out the account if too many failures occur
    /// - Parameter error: The error that occurred during login attempt
    private func handleLoginFailure(_ error: Error) {
        // Increment the failure count for this login session
        incrementFailureCount()

        // Check if maximum failure attempts have been reached
        if failureCount >= maxFailureAttempts {
            // Lock out the account for the specified duration
            lockoutTime = Date().addingTimeInterval(lockoutDuration)
            state = .lockedOut
        } else {
            // Show appropriate error message based on the error type
            if let loginError = error as? LoginError {
                state = .error(loginError.localizedDescription)
            } else {
                state = .error("Login failed")
            }
        }
    }

    /// Increments the failure count in UserDefaults
    /// Tracks failed login attempts across app sessions
    private func incrementFailureCount() {
        let currentCount = UserDefaults.standard.integer(forKey: failureCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: failureCountKey)
    }

    /// Resets the failure count and clears any lockout status
    /// Called when login is successful to reset security state
    private func resetFailureCount() {
        UserDefaults.standard.removeObject(forKey: failureCountKey)
        UserDefaults.standard.removeObject(forKey: lockoutTimeKey)
    }
}