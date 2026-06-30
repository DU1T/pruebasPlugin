//
//  Main.swift
//  UWBplugin
//
//  Created by Gustavo Gonzalez on 7/20/25.
//
import SwiftUI


@main
struct Main: App {
    @State private var viewModel = ViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .task {
                    // Deferred startup: first frame renders immediately showing
                    // the loading state, then UWB + Bluetooth initialization begins.
                    viewModel.startIfNeeded()
                }
        }
    }
}
