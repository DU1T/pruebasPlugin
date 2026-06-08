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
        }
    }
}
