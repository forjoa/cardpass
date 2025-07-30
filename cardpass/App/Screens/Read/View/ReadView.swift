//
//  ReadView.swift
//  cardpass
//
//  Created by Joaquín Trujillo on 30/7/25.
//
import Foundation
import SwiftUI

struct ReadView: View {
    @StateObject var viewModel = ReadViewModel()
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "key")
                Text("Reading your tag to show your passwords")
            }
            
            VStack {
                if viewModel.firstTime {
                    Button(action: {
                        viewModel.readTag()
                    }) {
                        Label("Read tag", systemImage: "key.card")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding()
                } else {
                    List(viewModel.passwords, id: \.id) { password in
                        Text(password.email)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .frame(width: .infinity, height: .infinity)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        
    }
}
