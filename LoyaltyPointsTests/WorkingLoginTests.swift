import XCTest
@testable import LoyaltyPoints

/// Working XCTest implementation that covers all 6 login test scenarios
/// Uses isolated test doubles to avoid system dependencies that cause crashes
final class WorkingLoginTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test to prevent cross-test contamination
        // Using exact key names from LoginViewModel and AuthService
        UserDefaults.standard.removeObject(forKey: "login_failure_count")
        UserDefaults.standard.removeObject(forKey: "lockout_time")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "auth_token_expiration")
    }

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "login_failure_count")
        UserDefaults.standard.removeObject(forKey: "lockout_time")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "auth_token_expiration")
        super.tearDown()
    }

    // MARK: - Test 1: Validation enables/disables button

    func testValidationEnablesDisablesButton() {
        // Use isolated test approach to verify form validation logic
        let authService = IsolatedAuthService()
        let networkMonitor = IsolatedNetworkMonitor()

        let viewModel = LoginViewModel(authService: authService, networkMonitor: networkMonitor)

        // Test initial state
        XCTAssertFalse(viewModel.isFormValid, "Empty form should be invalid")

        // Test username only
        viewModel.username = "test"
        // Give a moment for Combine validation to process
        let expectation1 = expectation(description: "Username validation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)

        XCTAssertFalse(viewModel.isFormValid, "Username only should be invalid")

        // Test both fields
        viewModel.password = "password"
        let expectation2 = expectation(description: "Complete form validation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)

        XCTAssertTrue(viewModel.isFormValid, "Complete form should be valid")

        // Test whitespace only
        viewModel.username = "   "
        viewModel.password = "   "
        let expectation3 = expectation(description: "Whitespace validation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 1.0)

        XCTAssertFalse(viewModel.isFormValid, "Whitespace only should be invalid")
    }

    // MARK: - Test 2: Success → navigation event

    func testSuccessTriggersNavigationEvent() async {
        let authService = IsolatedAuthService()
        let networkMonitor = IsolatedNetworkMonitor()
        networkMonitor.isConnected = true

        let viewModel = LoginViewModel(authService: authService, networkMonitor: networkMonitor)

        viewModel.username = "user"
        viewModel.password = "password"

        XCTAssertEqual(viewModel.state, .idle, "Should start in idle state")

        viewModel.login()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.state, .success, "Should be in success state after successful login")
    }

    // MARK: - Test 3: Error increments failure count

    func testErrorIncrementsFailureCount() async {
        let authService = IsolatedAuthService()
        let networkMonitor = IsolatedNetworkMonitor()
        networkMonitor.isConnected = true

        let viewModel = LoginViewModel(authService: authService, networkMonitor: networkMonitor)

        let initialFailureCount = viewModel.failureCount

        viewModel.username = "wrong"
        viewModel.password = "wrong"

        viewModel.login()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.failureCount, initialFailureCount + 1, "Failure count should increment")

        if case .error(let message) = viewModel.state {
            XCTAssertEqual(message, "Invalid username or password", "Should show correct error")
        } else {
            XCTFail("State should be error")
        }
    }

    // MARK: - Test 4: Lockout after 3 failures

    func testLockoutAfterThreeFailures() async {
        let authService = IsolatedAuthService()
        let networkMonitor = IsolatedNetworkMonitor()
        networkMonitor.isConnected = true

        let viewModel = LoginViewModel(authService: authService, networkMonitor: networkMonitor)

        viewModel.username = "wrong"
        viewModel.password = "wrong"

        // Perform 3 failed attempts
        for _ in 1...3 {
            viewModel.login()
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        XCTAssertTrue(viewModel.isLockedOut, "Account should be locked after 3 failures")

        // Try another login - should immediately show lockout
        viewModel.login()
        XCTAssertEqual(viewModel.state, .lockedOut, "Should show lockout state")
    }

    // MARK: - Test 5: Offline → show message, no service call

    func testOfflineShowsMessageWithoutServiceCall() {
        let authService = SpyIsolatedAuthService()
        let networkMonitor = IsolatedNetworkMonitor()
        networkMonitor.isConnected = false

        let viewModel = LoginViewModel(authService: authService, networkMonitor: networkMonitor)

        viewModel.username = "user"
        viewModel.password = "password"

        let initialCallCount = authService.loginCallCount

        viewModel.login()

        // Give a moment for the state to update
        let expectation = expectation(description: "Offline state update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(authService.loginCallCount, initialCallCount, "Auth service should not be called when offline")

        if case .error(let message) = viewModel.state {
            XCTAssertEqual(message, "No internet connection", "Should show offline message")
        } else {
            XCTFail("State should be error with offline message, but was: \(viewModel.state)")
        }
    }

    // MARK: - Test 6: Remember me persists token

    func testRememberMePersistsToken() async {
        let authService = SpyIsolatedAuthService()
        let networkMonitor = IsolatedNetworkMonitor()
        networkMonitor.isConnected = true

        let viewModel = LoginViewModel(authService: authService, networkMonitor: networkMonitor)

        viewModel.username = "user"
        viewModel.password = "password"
        viewModel.rememberMe = true

        viewModel.login()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(authService.saveTokenCalled, "saveToken should be called when rememberMe is true")
        XCTAssertEqual(viewModel.state, .success, "Login should succeed")
    }

    func testRememberMeDisabledDoesNotPersistToken() async {
        let authService = SpyIsolatedAuthService()
        let networkMonitor = IsolatedNetworkMonitor()
        networkMonitor.isConnected = true

        let viewModel = LoginViewModel(authService: authService, networkMonitor: networkMonitor)

        viewModel.username = "user"
        viewModel.password = "password"
        viewModel.rememberMe = false

        viewModel.login()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(authService.saveTokenCalled, "saveToken should not be called when rememberMe is false")
        XCTAssertEqual(viewModel.state, .success, "Login should still succeed")
    }
}

// MARK: - Isolated Test Doubles (No system dependencies)

/// Completely isolated NetworkMonitor that doesn't inherit from the real one
class IsolatedNetworkMonitor: NetworkMonitor {
    private var _isConnected = true

    override var isConnected: Bool {
        get { return _isConnected }
        set { _isConnected = newValue }
    }

    override init() {
        super.init()
        // Override immediately to prevent system calls
        _isConnected = true
    }
}

/// Simple auth service for testing
class IsolatedAuthService: AuthServiceProtocol {
    func login(username: String, password: String) async throws -> AuthToken {
        try await Task.sleep(nanoseconds: 100_000_000)

        if username == "user" && password == "password" {
            return AuthToken(token: "test-token", expirationDate: Date().addingTimeInterval(3600))
        } else {
            throw LoginError.invalidCredentials
        }
    }

    func getSavedToken() -> AuthToken? {
        return nil
    }

    func saveToken(_ token: AuthToken) {
        // Mock implementation
    }

    func clearSavedToken() {
        // Mock implementation
    }
}

/// Spy service that tracks calls
class SpyIsolatedAuthService: AuthServiceProtocol {
    var loginCallCount = 0
    var saveTokenCalled = false

    func login(username: String, password: String) async throws -> AuthToken {
        loginCallCount += 1
        try await Task.sleep(nanoseconds: 100_000_000)

        if username == "user" && password == "password" {
            return AuthToken(token: "test-token", expirationDate: Date().addingTimeInterval(3600))
        } else {
            throw LoginError.invalidCredentials
        }
    }

    func getSavedToken() -> AuthToken? {
        return nil
    }

    func saveToken(_ token: AuthToken) {
        saveTokenCalled = true
    }

    func clearSavedToken() {
        saveTokenCalled = false
    }
}