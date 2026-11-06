//
//  FeatureSettingsView.swift
//  Trio
//
//  Created by Deniz Cengiz on 26.07.24.
//
import Foundation
import HealthKit
import SwiftUI
import Swinject

struct ServicesView: BaseView {
    let resolver: Resolver

    @ObservedObject var state: Settings.StateModel

    @Environment(\.colorScheme) var colorScheme
    @Environment(AppState.self) var appState

    @State private var showPumpArchive = false

    var body: some View {
        Form {
            Section(
                header: Text("Connected Services"),
                content: {
                    Text("Nightscout").navigationLink(to: .nighscoutConfig, from: self)
                    Text("Tidepool").navigationLink(to: .tidepoolConfig, from: self)
                    if HKHealthStore.isHealthDataAvailable() {
                        Text("Apple Health").navigationLink(to: .healthkit, from: self)
                    }
                    Button("Pump Archive") { showPumpArchive = true }
                        .foregroundColor(.primary)
                }
            )
            .listRowBackground(Color.chart)
        }
        .sheet(isPresented: $showPumpArchive) {
            PumpArchiveSettingsView(service: PumpArchiveManager.shared.service) { showPumpArchive = false }
        }
        .scrollContentBackground(.hidden)
        .background(appState.trioBackgroundColor(for: colorScheme))
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.automatic)
    }
}
