import SwiftUI

/// SwiftUI view that presents the login interface to the user
/// Follows MVVM pattern by binding to LoginViewModel for state management
/// Provides a clean, accessible interface with proper validation feedback
struct LoginView: View {
    // MARK: - State Properties

    /// ViewModel that manages login business logic and state
    /// ObservedObject allows external injection of the viewModel
    @ObservedObject var viewModel: LoginViewModel

    /// Controls whether the success alert is shown to the user
    @State private var showSuccessAlert = false

    // MARK: - View Body

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // MARK: - Header Section
                headerSection

                // MARK: - Form Section
                formSection

                // MARK: - Login Button Section
                loginButtonSection

                // MARK: - Error Display Section
                errorDisplaySection

                // MARK: - Lockout Display Section
                lockoutDisplaySection

                Spacer()
            }
            .navigationBarHidden(true)
            .onChange(of: viewModel.state) { state in
                // Show success alert when login is successful
                if case .success = state {
                    showSuccessAlert = true
                }
            }
            .alert("Login Successful", isPresented: $showSuccessAlert) {
                Button("OK") {
                    // Handle navigation to main app or dismiss modal
                    // In a real app, this would trigger navigation to the main interface
                }
            } message: {
                Text("You have successfully logged in.")
            }
        }
    }

    // MARK: - View Components

    /// Header section containing the main title
    private var headerSection: some View {
        Text("Login")
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding(.top, 50)
            .accessibilityIdentifier("loginTitle")
    }

    /// Form section containing input fields and remember me toggle
    private var formSection: some View {
        VStack(spacing: 16) {
            // Username input field
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none) // Prevent automatic capitalization for usernames
                .disableAutocorrection(true) // Disable autocorrect for usernames
                .accessibilityIdentifier("usernameField")
                .accessibilityLabel("Username")
                .accessibilityHint("Enter your username")

            // Password input field with secure text entry
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityIdentifier("passwordField")
                .accessibilityLabel("Password")
                .accessibilityHint("Enter your password")

            // Remember me toggle aligned to the left
            HStack {
                Toggle("Remember Me", isOn: $viewModel.rememberMe)
                    .accessibilityIdentifier("rememberMeToggle")
                    .accessibilityLabel("Remember Me")
                    .accessibilityHint("Keep me logged in on this device")
                Spacer()
            }
        }
        .padding(.horizontal)
    }

    /// Login button section with loading state and validation
    private var loginButtonSection: some View {
        Button(action: {
            viewModel.login()
        }) {
            HStack {
                // Show loading indicator when login is in progress
                if case .loading = viewModel.state {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

                Text("Login")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isFormValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!viewModel.isFormValid || viewModel.state == .loading)
        .padding(.horizontal)
        .accessibilityIdentifier("loginButton")
        .accessibilityLabel("Login")
        .accessibilityHint(viewModel.isFormValid ? "Tap to log in" : "Complete the form to enable login")
    }

    /// Error display section that shows validation and authentication errors
    private var errorDisplaySection: some View {
        Group {
            // Only show error message if the current state is an error
            if case .error(let message) = viewModel.state {
                VStack(spacing: 8) {
                    Text(message)
                        .foregroundColor(.red)
                        .font(.body)

                    // Show failure count when there are failed attempts
                    if viewModel.failureCount > 0 {
                        Text("Failed attempts: \(viewModel.failureCount)/\(viewModel.maxFailureAttempts)")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .accessibilityIdentifier("errorMessage")
                .accessibilityLabel("Error")
                .accessibilityValue(message)
            }
        }
    }

    /// Lockout display section that shows when the account is locked
    private var lockoutDisplaySection: some View {
        Group {
            // Only show lockout message if the current state is locked out
            if case .lockedOut = viewModel.state {
                VStack {
                    // Lock icon to visually indicate lockout status
                    Image(systemName: "lock.fill")
                        .foregroundColor(.red)
                        .font(.title)

                    Text("Account Locked")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text("Too many failed attempts. Try again later.")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .accessibilityIdentifier("lockoutMessage")
                .accessibilityLabel("Account Locked")
                .accessibilityValue("Too many failed attempts. Try again later.")
            }
        }
    }
}

// MARK: - Preview Provider

/// Provides previews for the LoginView in Xcode's canvas
/// Useful for UI development and visual testing
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(viewModel: LoginViewModel())
    }
}