//
//  TaskAdvance.swift
//  My First AVP CloudXR Client
//
//  Moving the session on from one task screen to the next.
//
//  Progression used to be implicit: the pre-flight opened Task 1 itself, but
//  Task 1's "Confirm" only set a local flag, so a participant who confirmed sat
//  looking at a dead button while nothing happened. The order of the session was
//  scattered across whichever button happened to call openWindow.
//
//  The order now lives in one place (`TaskID.next`) and every screen advances the
//  same way.
//

import SwiftUI

/// Advances from `current` to the next screen in the round.
///
/// Both the window and the Firestore trigger are updated. The trigger alone is not
/// enough, because a window may have been opened by a button rather than by a
/// trigger — the pre-flight does exactly that — and clearing a trigger that was
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
