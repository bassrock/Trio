import Foundation
import LoopKit
import PumpArchiveKit

/// Hosts PumpArchiveKit's service, which archives a Tandem Mobi's raw history and settings to
/// the user's own `pump-archive` server.
///
/// Loop loads the service as a plugin and feeds it through its service hooks. Trio has no
/// plugin host for services, so this does the same job by hand:
/// - the pump manager, whenever `DeviceDataManager` sets or clears it;
/// - the driver's own dose events, as they arrive (`DoseEntry` carries TandemKit's sync
///   identifier, which tells the archive which pump bolus each one was, and whether the
///   algorithm gave it);
/// - carbs the user enters, so the archive can pair them with their bolus.
///
/// The service reads the pump and uploads on its own schedule; each dose report is the trigger
/// to check whether an upload is due. It does nothing until it's turned on in
/// Settings → Services → Pump Archive. Non-Tandem pumps are ignored.
final class PumpArchiveManager: StatefulPluggableDelegate {
    static let shared = PumpArchiveManager()

    @PersistedProperty(key: "PumpArchiveState") private var rawState: Service.RawStateValue?

    private let lock = NSLock()
    private var _service: PumpArchiveService
    private weak var pumpManager: PumpManager?

    /// Replaced by a fresh one when the user deletes it, so the settings screen always has one.
    var service: PumpArchiveService { lock.withLock { _service } }

    private init() {
        _service = PumpArchiveService()
        if let rawState, let restored = PumpArchiveService(rawState: rawState) {
            _service = restored
        }
        _service.stateDelegate = self
    }

    /// `DeviceDataManager` calls this whenever its pump manager changes, nil when it's removed.
    func pumpManagerChanged(_ newPumpManager: PumpManager?) {
        lock.withLock { pumpManager = newPumpManager }
        service.initializationComplete(for: [newPumpManager].compactMap { $0 })
    }

    /// The pump driver reported new events: passes their doses on, which also checks whether an
    /// upload is due.
    func pumpEventsReported(_ events: [NewPumpEvent]) {
        service.uploadDoseData(created: events.compactMap(\.dose), deleted: []) { _ in }
    }

    /// The user saved carbs in Trio (not ones fetched from Nightscout).
    func carbsEntered(_ entries: [CarbsEntry]) {
        let carbs = entries
            .filter { $0.isFPU != true && $0.carbs > 0 }
            .map { $0.convertSyncCarb() }
        guard !carbs.isEmpty else { return }
        service.uploadCarbData(created: carbs, updated: [], deleted: []) { _ in }
    }

    // MARK: StatefulPluggableDelegate

    func pluginDidUpdateState(_ plugin: StatefulPluggable) {
        guard plugin === service else { return }
        rawState = service.rawState
    }

    func pluginWantsDeletion(_ plugin: StatefulPluggable) {
        guard plugin === service else { return }
        info(.pump, "Pump Archive deleted; starting a fresh, disabled one")
        rawState = nil
        let fresh = PumpArchiveService()
        fresh.stateDelegate = self
        let pump = lock.withLock {
            _service = fresh
            return pumpManager
        }
        fresh.initializationComplete(for: [pump].compactMap { $0 })
    }
}
