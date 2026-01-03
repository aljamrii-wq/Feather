//
//  ArchiveHandler.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import Foundation
import UIKit.UIApplication
import Zip
import OSLog
import SwiftUI
import IDeviceSwift

final class ArchiveHandler: NSObject {
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private var _payloadUrl: URL?
	
	private var _app: AppInfoPresentable
	private let _uniqueWorkDir: URL
	
	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) {
		self.viewModel = viewModel
		self._app = app
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherInstall_\(_uuid)", isDirectory: true)
		
		super.init()
	}
	
	func move() async throws {
		guard let appUrl = Storage.shared.getAppDirectory(for: _app) else {
			throw SigningFileHandlerError.appNotFound
		}
		
		let payloadUrl = _uniqueWorkDir.appendingPathComponent("Payload")
		let movedAppURL = payloadUrl.appendingPathComponent(appUrl.lastPathComponent)

		try _fileManager.createDirectoryIfNeeded(at: payloadUrl)
		
		try _fileManager.copyItem(at: appUrl, to: movedAppURL)
		_payloadUrl = payloadUrl
	}
	
	func archive() async throws -> URL {
		guard let payloadUrl = self._payloadUrl else {
			throw SigningFileHandlerError.appNotFound
		}
		
		let zipUrl = self._uniqueWorkDir.appendingPathComponent("Archive.zip")
		let ipaUrl = self._uniqueWorkDir.appendingPathComponent("Archive.ipa")
		
		try await Task.detached(priority: .background) {
			try Zip.zipFiles(
				paths: [payloadUrl],
				zipFilePath: zipUrl,
				password: nil,
				compression: ZipCompression.allCases[ArchiveHandler.getCompressionLevel()],
				progress: { progress in
					Task { @MainActor in
						self.viewModel.packageProgress = progress
					}
				})
		}.value
		
		try FileManager.default.moveItem(at: zipUrl, to: ipaUrl)
		return ipaUrl
	}
	
	func moveToArchive(_ package: URL, shouldOpen: Bool = false) async throws -> URL? {
		let name = _sanitizeFilenameComponent(_app.name ?? "", fallback: "Unknown")
		let version = _sanitizeFilenameComponent(_app.version ?? "", fallback: "1.0")
		let timestamp = Int(Date().timeIntervalSince1970)
		let appendingString = "\(name)_\(version)_\(timestamp).ipa"
		let dest = _fileManager.archives.appendingPathComponent(appendingString)
		
		do {
			try _fileManager.moveItem(at: package, to: dest)
		} catch {
			OSLog.Logger.misc.error("Failed to move package to archive: \(error.localizedDescription)")
			throw error
		}
		
		if shouldOpen {
			if let sharedURL = FileManager.default.archives.toSharedDocumentsURL() {
				await MainActor.run {
					UIApplication.open(sharedURL)
				}
			}
		}
		
		return dest
	}
	
	static func getCompressionLevel() -> Int {
		UserDefaults.standard.integer(forKey: "Feather.compressionLevel")
	}
	
	private func _sanitizeFilenameComponent(_ value: String, fallback: String) -> String {
		let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
		let mapped = value.map { allowed.contains($0) ? $0 : "_" }
		let trimmed = String(mapped)
			.trimmingCharacters(in: CharacterSet(charactersIn: "._- "))
		
		if trimmed.isEmpty {
			return fallback
		}
		
		return String(trimmed.prefix(64))
	}
}
