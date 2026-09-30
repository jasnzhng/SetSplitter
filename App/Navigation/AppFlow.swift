//
//  AppFlow.swift
//  SetSplitter
//
//  implementation.md §10. The wizard is a plain enum-driven flow, simpler
//  than a NavigationStack for three linear screens.
//

import Foundation

enum AppFlow {

    enum Step: Int, CaseIterable, Comparable, Identifiable {
        case importFile
        case tracklist
        case export

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .importFile: "Import"
            case .tracklist: "Tracklist"
            case .export: "Export"
            }
        }

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}
