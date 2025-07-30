//
//  Password.swift
//  cardpass
//
//  Created by Joaquín Trujillo on 30/7/25.
//

import Foundation

struct Password: Codable {
    let id: UUID // identification
    let email: String // related to the password
    let password: String
    let site: String // related to the account information
    let createdAt: Date // creation time
}
