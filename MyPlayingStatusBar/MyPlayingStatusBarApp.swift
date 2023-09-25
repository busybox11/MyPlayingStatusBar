//
//  MyPlayingStatusBarApp.swift
//  MyPlayingStatusBar
//
//  Created by busy on 18/09/2023.
//

import SwiftUI
import AppKit
import Foundation
import Combine
import WebSocket

let socket = WebSocket()

struct NPProgress: Codable {
    let current: Int
    let duration: Int
    let playing: Bool
}

struct NowPlayingResponse: Codable {
    let album: String
    let albumArt: String
    let artist: String
    let id: String
    let name: String
    let progress: NPProgress
    let song: String
    let type: String
}

class WebSocketManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let socket = WebSocket()
    var object = NowPlayingResponse(album: "", albumArt: "", artist: "", id: "", name: "", progress: NPProgress(current: 0, duration: 0, playing: false), song: "", type: "") {
        didSet {
            objectWillChange.send()
        }
    }

    init() {
        socket.connect(url: URL(string: ProcessInfo.processInfo.environment["WEBSOCKET_SERVER"]!)!)

        socket.onConnected = { ws in
            print("connected")
            self.objectWillChange.send()
        }

        socket.onData = { data, ws in
            let JSON = data.text!
            // Parse JSON as NowPlayingResponse
            let decoder = JSONDecoder()
            let nowPlaying = try! decoder.decode(NowPlayingResponse.self, from: JSON.data(using: .utf8)!)

            // Update object
            self.object = nowPlaying
        }
    }
}

@main
struct MyPlayingStatusBarApp: App {
    @StateObject var websocket = WebSocketManager()

    var body: some Scene {
        MenuBarExtra {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        } label: {
            HStack {
                let image: NSImage? = {
                    guard let url = URL(string: websocket.object.albumArt), let data = try? Data(contentsOf: url) else {
                        return NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
                    }
                    return NSImage(data: data)
                }()
                let scaledImage = image?.resized(to: CGSize(width: 16, height: 16)).roundedImage(cornerRadius: 4)

                Image(nsImage: scaledImage ?? NSImage())

                Text(" " + websocket.object.name + " · " + websocket.object.artist)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

extension NSImage {
    func resized(to newSize: CGSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: self.size), operation: .copy, fraction: CGFloat(1))
        newImage.unlockFocus()
        return newImage
    }

    func roundedImage(cornerRadius: CGFloat) -> NSImage {
        let image = NSImage(size: self.size, flipped: false) { (rect) -> Bool in
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.addClip()
            self.draw(in: rect)
            return true
        }
        return image
    }
}
