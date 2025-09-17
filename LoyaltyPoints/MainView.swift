import SwiftUI

struct MainView: View {
    @StateObject private var loginViewModel = LoginViewModel()
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        ZStack {
            if loginViewModel.state == .success {
                ContentView(onLogout: logout)
                    .environment(\.managedObjectContext, viewContext)
            } else {
                LoginView(viewModel: loginViewModel)
            }
        }
        .onAppear {
            // Check for saved token when app launches
            loginViewModel.checkForSavedToken()
        }
    }

    private func logout() {
        loginViewModel.logout()
    }
}

#Preview {
    MainView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}