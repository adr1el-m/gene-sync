import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "rectangle.grid.2x2")
            }

            NavigationStack {
                AlignView()
            }
            .tabItem {
                Label("Align", systemImage: "arrow.left.arrow.right.square")
            }

            NavigationStack {
                MatrixView()
            }
            .tabItem {
                Label("Matrix", systemImage: "tablecells")
            }

            NavigationStack {
                ResultsView()
            }
            .tabItem {
                Label("Results", systemImage: "chart.bar.xaxis")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}
