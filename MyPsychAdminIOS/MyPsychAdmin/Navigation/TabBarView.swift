//
//  TabBarView.swift
//  MyPsychAdmin
//

import SwiftUI

struct TabBarView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        @Bindable var store = appStore

        TabView(selection: $store.activeTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)
        }
        .tint(Color(red: 0.13, green: 0.59, blue: 0.53))
    }
}

#Preview {
    TabBarView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
