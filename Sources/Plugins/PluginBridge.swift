//
//  PluginBridge.swift
//  YT Music
//
//

import SwiftUI

private struct PluginBridge: ViewModifier {
    let player: PlayerState
    let host: PluginHost

    func body(content: Content) -> some View {
        content.onAppear {
            player.onPlaybackChange = { [weak host] snapshot in
                host?.playbackDidChange(snapshot)
            }
            player.onPlaybackProgress = { [weak host] currentTime, duration in
                host?.playbackDidProgress(currentTime: currentTime, duration: duration)
            }
            host.playbackDidChange(player.currentSnapshot)
        }
    }
}

extension View {
    func pluginBridge(player: PlayerState, host: PluginHost) -> some View {
        modifier(PluginBridge(player: player, host: host))
    }
}
