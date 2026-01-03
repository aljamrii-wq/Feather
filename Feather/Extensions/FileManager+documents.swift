//
//  FileManager+documents.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import Foundation.NSFileManager

extension FileManager {
	private var _applicationSupportBase: URL {
		let base = urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL.documentsDirectory
		let bundleId = Bundle.main.bundleIdentifier ?? "Feather"
		return base.appendingPathComponent(bundleId, isDirectory: true)
	}
	
	/// Gives apps Signed directory
	var archives: URL {
		URL.documentsDirectory.appendingPathComponent("Archives")
	}
	
	/// Gives apps Signed directory
	var signed: URL {
		URL.documentsDirectory.appendingPathComponent("Signed")
	}
	
	/// Gives apps Signed directory with a UUID appending path
	func signed(_ uuid: String) -> URL {
		signed.appendingPathComponent(uuid)
	}
	
	/// Gives apps Unsigned directory
	var unsigned: URL {
		URL.documentsDirectory.appendingPathComponent("Unsigned")
	}
	
	/// Gives apps Unsigned directory with a UUID appending path
	func unsigned(_ uuid: String) -> URL {
		unsigned.appendingPathComponent(uuid)
	}
	
	/// Gives apps Certificates directory
	var certificates: URL {
		_applicationSupportBase.appendingPathComponent("Certificates")
	}
	/// Gives apps Certificates directory with a UUID appending path
	func certificates(_ uuid: String) -> URL {
		certificates.appendingPathComponent(uuid)
	}
	
	func migrateCertificatesIfNeeded() {
		let legacyCertificates = URL.documentsDirectory.appendingPathComponent("Certificates")
		guard fileExists(atPath: legacyCertificates.path) else { return }
		
		let newCertificates = certificates
		
		do {
			try createDirectory(at: newCertificates, withIntermediateDirectories: true)
			let items = try contentsOfDirectory(at: legacyCertificates, includingPropertiesForKeys: nil)
			
			for item in items {
				let destination = newCertificates.appendingPathComponent(item.lastPathComponent)
				if fileExists(atPath: destination.path) { continue }
				try moveItem(at: item, to: destination)
			}
			
			try? removeItem(at: legacyCertificates)
		} catch {
			// Best-effort migration only.
		}
	}
}
