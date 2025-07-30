//
//  ContentView.swift
//  cardpass
//
//  Created by Joaquín Trujillo on 30/7/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WriteView().navigationTitle("Write")
            }.tabItem {
                Label("Write", systemImage: "pencil")
            }
            
            NavigationStack {
                ReadView().navigationTitle("Read")
            }.tabItem {
                Label("Read", systemImage: "book")
            }
        }
    }
}

#Preview {
    ContentView()
}
