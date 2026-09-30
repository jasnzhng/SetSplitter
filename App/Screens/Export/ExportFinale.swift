//
//  ExportFinale.swift
//  SetSplitter
//
//  The state of the export's closing animation. Each field is animated on its own
//  schedule by `ExportStage`, so the steps can overlap and use different curves.
//

import Foundation

struct ExportFinale: Equatable {

    /// The percentage, track label, Cancel button and timeline strip have faded away.
    var progressGone = false
    /// The cover (as a sleeve) has faded in where the percentage was.
    var sleeveShown = false
    /// The tonearm has lifted away and faded out.
    var armGone = false
    /// The record has stopped turning (it stops just before sliding in).
    var recordStopped = false
    /// 0 = record beside the sleeve, 1 = slid in, with just a sliver poking out of the open edge.
    var recordSlide: Double = 0
    /// The sleeve has glided left and the "album is ready" details are showing.
    var settled = false

    /// Everything done — used when the stage is created already finished, and under Reduce Motion.
    static let complete = ExportFinale(
        progressGone: true, sleeveShown: true, armGone: true, recordStopped: true, recordSlide: 1, settled: true)
}
