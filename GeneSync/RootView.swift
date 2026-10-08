import SwiftUI

private enum AppTab: Hashable {
    case home
    case align
    case matrix
    case results
    case history
}

struct RootView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "rectangle.grid.2x2")
            }
            .tag(AppTab.home)

            NavigationStack {
                AlignView()
            }
            .tabItem {
                Label("Align", systemImage: "arrow.left.arrow.right.square")
            }
            .tag(AppTab.align)

            NavigationStack {
                MatrixView()
            }
            .tabItem {
                Label("Matrix", systemImage: "tablecells")
            }
            .tag(AppTab.matrix)

            NavigationStack {
                ResultsView()
            }
            .tabItem {
                Label("Results", systemImage: "chart.bar.xaxis")
            }
            .tag(AppTab.results)

            NavigationStack {
                HistoryView {
                    selectedTab = .results
                }
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.history)
        }
    }
}
