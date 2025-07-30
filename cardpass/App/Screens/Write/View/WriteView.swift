//
//  WriteView.swift
//  cardpass
//
//  Created by Joaquín Trujillo on 30/7/25.
//
import Foundation
import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .font(.headline)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct WriteView: View {
    @StateObject var viewModel: WriteViewModel = WriteViewModel()
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "mail")
                Text("Email")
            }.frame(maxWidth: .infinity, alignment: .leading)
            TextField("Email", text: $viewModel.email).textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Image(systemName: "key")
                Text("Password")
            }.frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Group {
                    if !viewModel.passwordShown {
                        SecureField("Password", text: $viewModel.password)
                    } else {
                        TextField("Password", text: $viewModel.password)
                    }
                }
                Button(action: {
                    viewModel.passwordShown.toggle()
                }) {
                    Image(systemName: viewModel.passwordShown ? "eye.slash" : "eye")
                }
            }
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            HStack {
                Image(systemName: "network")
                Text("Site URL")
            }.frame(maxWidth: .infinity, alignment: .leading)
            TextField("Website or App", text: $viewModel.site).textFieldStyle(RoundedBorderTextFieldStyle())
            
            Spacer()
            
            Button(action: {
                viewModel.writeToTag()
            }) {
                Label("Write in tag", systemImage: "key.card")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
