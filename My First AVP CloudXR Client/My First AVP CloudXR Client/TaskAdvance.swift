//
//  TaskAdvance.swift
//  My First AVP CloudXR Client
//
//  Moving the session on from one move to the next.
//
//  Progression used to be implicit: one screen opened the next itself, while another
//  screen's button only set a local flag, so a participant who pressed it sat looking
//  at a dead control while nothing happened. The order of the session was scattered
//  across whichever button happened to call openWindow.
//
//  The order now lives in one place (`TaskID.next`) and every move advances the same
//  way: brief → work → review, then stop, because the questionnaire is off-headset.
//

import SwiftUI

/// Advances from `current` to the next move in the round.
///
/// Both the window and the Firestore trigger are updated. The trigger alone is not
/// enough, because a window may have been opened by a button rather than by a
/// trigger — the master window does exactly that — and clearing a trigger that was
/// never set leaves the old window sitting next to the new one. Writing the trigger
/// as well keeps the experimenter's console showing where the participant actually
/// is, rather than where they were when the last flag was flipped by hand.
@MainActor
func advance(from current: TaskID,
             autoAdvance: Bool,
             syncService: PrototypeSyncService,
             openWindow: OpenWindowAction,
             dismiss: DismissAction) {

    // Manual pacing: the experimenter drives everything from Firestore instead.
    guard autoAdvance else { return }

    // Last screen of the round — leave it up. The questionnaire comes next, and
    // that is off-headset.
    guard let next = current.next else { return }

    Task { await syncService.advance(from: current, to: next) }

    openWindow(id: "task", value: next)
    dismiss()
}
