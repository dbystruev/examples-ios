//
//  ConversationMessage.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 07.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

enum MessageType: String {
    
    case user = "UserMessageCell"
    case reply = "ServerMessageCell"
    case command = "CommandCell"
    case error = "ErrorCell"
    case commandResult = "CommandResultCell"
    case transcribeResult = "TranscribeCell"
    
}

struct Message {
    
    var text: String
    var type: MessageType
    
}
