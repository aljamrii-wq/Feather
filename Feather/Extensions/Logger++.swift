//
//  Logger++.swift
//  Feather
//
//  Created by samara on 24.05.2025.
//

import OSLog

extension Logger {
	private static var subsystem = Bundle.main.bundleIdentifier!
	static let signing = Logger(subsystem: subsystem, category: "Signing")
	static let storage = Logger(subsystem: subsystem, category: "Storage")
	static let downloads = Logger(subsystem: subsystem, category: "Downloads")
	static let misc = Logger(subsystem: subsystem, category: "Misc")
}
