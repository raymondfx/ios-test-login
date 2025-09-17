import XCTest
import Combine
@testable import LoyaltyPoints

// MARK: - Mock Objects

/// Mock implementation of AuthServiceProtocol for testing purposes
/// Allows controlled testing of different authentication scenarios
class MockAuthService: AuthServiceProtocol {
    // MARK: - Test Configuration Properties

    /// Controls whether the login attempt should succeed or fail
    var shouldSucceed = true

    /// Controls whether the service should simulate a network error
    var shouldThrowNetworkError = false

    /// Tracks the number of times login was called for verification
    var loginCallCount = 0

    // MARK: - AuthServiceProtocol Implementation

    /// Mock implementation of the login method
    /// Returns different results based on test configuration
    /// - Parameters:
    ///   - username: The username to authenticate (ignored in mock)
    ///   - password: The password to authenticate (ignored in mock)
    /// - Returns: A mock AuthToken if configured to succeed
    /// - Throws: Various LoginErrors based on test configuration
    func login(username: String, password: String) async throws -> AuthToken {
        loginCallCount += 1

        // Simulate network error if configured
        if shouldThrowNetworkError {
            throw LoginError.networkError
        }

        // Return success or failure based on configuration
        if shouldSucceed && username == "user" && password == "password" {
            return AuthToken(token: "mock_token", expirationDate: Date().addingTimeInterval(3600))
        } else {
            throw LoginError.invalidCredentials
        }
    }
}

/// Mock implementation of NetworkMonitor for testing offline scenarios
/// Allows controlled testing of network connectivity states
class MockNetworkMonitor: NetworkMonitor {
    /// Published property that controls the mock network state
    @Published var mockIsConnected = true

    /// Override the parent's isConnected property to return our mock value
    override var isConnected: Bool {
        return mockIsConnected
    }
}

// MARK: - Test Suite

/// Comprehensive test suite for LoginViewModel
/// Tests all major functionality including validation, authentication, error handling, and security features
class LoginViewModelTests: XCTestCase {
    // MARK: - Test Properties

    /// The view model under test
    var viewModel: LoginViewModel!

    /// Mock authentication service for controlled testing
    var mockAuthService: MockAuthService!

    /// Mock network monitor for testing offline scenarios
    var mockNetworkMonitor: MockNetworkMonitor!

    /// Set to store Combine subscriptions during testing
    var cancellables: Set<AnyCancellable>!

    // MARK: - Test Lifecycle

    /// Sets up test environment before each test method
    /// Creates fresh instances and clears any persistent state
    override func setUp() {
        super.setUp()

        // Create fresh mock objects for each test
        mockAuthService = MockAuthService()
        mockNetworkMonitor = MockNetworkMonitor()

        // Initialize view model with mock dependencies
        viewModel = LoginViewModel(authService: mockAuthService, networkMonitor: mockNetworkMonitor)

        // Create fresh cancellables set for each test
        cancellables = Set<AnyCancellable>()

        // Clear any saved state from previous tests to ensure clean test environment
        UserDefaults.standard.removeObject(forKey: "login_failure_count")
        UserDefaults.standard.removeObject(forKey: "lockout_time")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "auth_token_expiration")
    }

    /// Cleans up test environment after each test method
    /// Prevents memory leaks and state pollution between tests
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockAuthService = nil
        mockNetworkMonitor = nil
        super.tearDown()
    }

    // MARK: - Test 1: Form Validation

    /// Tests that form validation correctly enables and disables the login button
    /// Validates that both username and password must be non-empty for the form to be valid
    func testFormValidation() {
        // Initially the form should be invalid (empty fields)
        XCTAssertFalse(viewModel.isFormValid, "Form should be invalid when both fields are empty")

        // Form should remain invalid with only username filled
        viewModel.username = "user"
        XCTAssertFalse(viewModel.isFormValid, "Form should be invalid when password is empty")

        // Form should be valid when both fields are filled
        viewModel.password = "password"
        XCTAssertTrue(viewModel.isFormValid, "Form should be valid when both fields are filled")

        // Form should become invalid when password is cleared
        viewModel.password = ""
        XCTAssertFalse(viewModel.isFormValid, "Form should be invalid when password is cleared")

        // Form should be invalid with whitespace-only content
        viewModel.username = "   "
        viewModel.password = "   "
        XCTAssertFalse(viewModel.isFormValid, "Form should be invalid with whitespace-only content")
    }

    // MARK: - Test 2: Successful Authentication

    /// Tests that successful login triggers the correct state transition
    /// Verifies that the authentication service is called and success state is set
    func testSuccessfulLogin() async {
        let expectation = XCTestExpectation(description: "Login success")

        // Configure test scenario for successful login
        viewModel.username = "user"
        viewModel.password = "password"
        mockAuthService.shouldSucceed = true

        // Subscribe to state changes to detect success
        viewModel.$state
            .sink { state in
                if case .success = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Trigger the login attempt
        viewModel.login()

        // Wait for the async operation to complete
        await fulfillment(of: [expectation], timeout: 2.0)

        // Verify that the authentication service was called
        XCTAssertEqual(mockAuthService.loginCallCount, 1, "Auth service should be called exactly once")
    }

    // MARK: - Test 3: Failed Authentication

    /// Tests that failed login attempts increment the failure counter
    /// Verifies proper error handling and failure tracking
    func testFailureIncrementsCount() async {
        let expectation = XCTestExpectation(description: "Login failure")

        // Configure test scenario for failed login
        viewModel.username = "user"
        viewModel.password = "wrong"
        mockAuthService.shouldSucceed = false

        // Subscribe to state changes to detect error
        viewModel.$state
            .sink { state in
                if case .error = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Trigger the login attempt
        viewModel.login()

        // Wait for the async operation to complete
        await fulfillment(of: [expectation], timeout: 2.0)

        // Verify that the failure count was incremented
        let failureCount = UserDefaults.standard.integer(forKey: "login_failure_count")
        XCTAssertEqual(failureCount, 1, "Failure count should be incremented after failed login")
    }

    // MARK: - Test 4: Account Lockout

    /// Tests that the account is locked after 3 consecutive failed attempts
    /// Verifies the security mechanism prevents brute force attacks
    func testLockoutAfterThreeFailures() async {
        // Configure test scenario for repeated failures
        viewModel.username = "user"
        viewModel.password = "wrong"
        mockAuthService.shouldSucceed = false

        // First failure attempt
        let firstExpectation = XCTestExpectation(description: "First failure")
        viewModel.$state
            .sink { state in
                if case .error = state {
                    firstExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.login()
        await fulfillment(of: [firstExpectation], timeout: 2.0)

        // Second failure attempt
        let secondExpectation = XCTestExpectation(description: "Second failure")
        viewModel.$state
            .dropFirst() // Skip the first state change we already handled
            .sink { state in
                if case .error = state {
                    secondExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.login()
        await fulfillment(of: [secondExpectation], timeout: 2.0)

        // Third failure attempt should trigger lockout
        let lockoutExpectation = XCTestExpectation(description: "Lockout")
        viewModel.$state
            .dropFirst(2) // Skip the first two state changes
            .sink { state in
                if case .lockedOut = state {
                    lockoutExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.login()
        await fulfillment(of: [lockoutExpectation], timeout: 2.0)

        // Verify that the account is indeed locked out
        XCTAssertTrue(viewModel.isLockedOut, "Account should be locked out after 3 failed attempts")
    }

    // MARK: - Test 5: Offline Handling

    /// Tests that offline state prevents login attempts and shows appropriate message
    /// Verifies that no network calls are made when offline
    func testOfflineHandling() async {
        let expectation = XCTestExpectation(description: "Offline error")

        // Configure test scenario for offline state
        viewModel.username = "user"
        viewModel.password = "password"
        mockNetworkMonitor.mockIsConnected = false

        // Subscribe to state changes to detect offline error
        viewModel.$state
            .sink { state in
                if case .error(let message) = state {
                    XCTAssertEqual(message, "No internet connection", "Should show offline error message")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Trigger the login attempt
        viewModel.login()

        // Wait for the immediate response (no network delay when offline)
        await fulfillment(of: [expectation], timeout: 1.0)

        // Verify that no network call was made
        XCTAssertEqual(mockAuthService.loginCallCount, 0, "Auth service should not be called when offline")
    }

    // MARK: - Test 6: Remember Me Functionality

    /// Tests that the "Remember Me" feature correctly persists authentication tokens
    /// Verifies token storage and cleanup behavior
    func testRememberMePersistsToken() async {
        let expectation = XCTestExpectation(description: "Token saved")

        // Configure test scenario for successful login with Remember Me enabled
        viewModel.username = "user"
        viewModel.password = "password"
        viewModel.rememberMe = true
        mockAuthService.shouldSucceed = true

        // Subscribe to state changes to detect success
        viewModel.$state
            .sink { state in
                if case .success = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Trigger the login attempt
        viewModel.login()

        // Wait for the async operation to complete
        await fulfillment(of: [expectation], timeout: 2.0)

        // Verify that the token was saved to UserDefaults
        let savedToken = UserDefaults.standard.string(forKey: "auth_token")
        XCTAssertNotNil(savedToken, "Token should be saved when Remember Me is enabled")

        // Test the opposite scenario - login without Remember Me
        viewModel.logout()
        viewModel.rememberMe = false

        let secondExpectation = XCTestExpectation(description: "Token not saved")
        viewModel.$state
            .sink { state in
                if case .success = state {
                    secondExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.login()
        await fulfillment(of: [secondExpectation], timeout: 2.0)

        // Verify that the token was cleared since Remember Me was disabled
        let tokenAfterLogout = UserDefaults.standard.string(forKey: "auth_token")
        XCTAssertNil(tokenAfterLogout, "Token should be cleared when Remember Me is disabled")
    }

    // MARK: - Test 7: Lockout Prevention

    /// Tests that locked accounts cannot attempt login until lockout period expires
    /// Verifies that the security mechanism properly prevents login attempts during lockout
    func testLockoutPreventsLoginAttempts() {
        // Manually simulate a locked out state by setting UserDefaults
        UserDefaults.standard.set(3, forKey: "login_failure_count")
        UserDefaults.standard.set(Date().addingTimeInterval(300), forKey: "lockout_time") // 5 minutes from now

        // Configure valid credentials
        viewModel.username = "user"
        viewModel.password = "password"

        // Attempt to login while locked out
        viewModel.login()

        // Verify that no network call was made due to lockout
        XCTAssertEqual(mockAuthService.loginCallCount, 0, "Auth service should not be called during lockout")

        // Verify that the state reflects the lockout condition
        if case .lockedOut = viewModel.state {
            // Test passes - lockout state is correctly set
        } else {
            XCTFail("Expected lockout state when account is locked")
        }
    }
}