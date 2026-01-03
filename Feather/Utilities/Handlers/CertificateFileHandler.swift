//
//  CertificateFileHandler.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import Foundation
import OSLog

final class CertificateFileHandler: NSObject {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	
	private let _key: URL
	private let _provision: URL
	private let _keyPassword: String?
	private let _certNickname: String?
	private let _isDefault: Bool
	
	private var _certPair: Certificate?
	
	init(
		key: URL,
		provision: URL,
		password: String? = nil,
		nickname: String? = nil,
		isDefault: Bool = false
	) {
		self._key = key
		self._provision = provision
		self._keyPassword = password
		self._certNickname = nickname
		self._isDefault = isDefault
		
		_certPair = CertificateReader(provision).decoded
		
		super.init()
	}
	
	func copy() async throws {
		guard _certPair != nil else {
			throw CertificateFileHandlerError.certNotValid
		}
		
		let destinationURL = try await _directory()

			do {
				try _fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
				
				let keyDestination = destinationURL.appendingPathComponent(_key.lastPathComponent)
				let provisionDestination = destinationURL.appendingPathComponent(_provision.lastPathComponent)
				
				try _fileManager.copyItem(at: _key, to: keyDestination)
				try _fileManager.copyItem(at: _provision, to: provisionDestination)
				
				let protection: [FileAttributeKey: Any] = [
					.protectionKey: FileProtectionType.complete
				]
				try? _fileManager.setAttributes(protection, ofItemAtPath: destinationURL.path)
				try? _fileManager.setAttributes(protection, ofItemAtPath: keyDestination.path)
				try? _fileManager.setAttributes(protection, ofItemAtPath: provisionDestination.path)
			} catch {
			Logger.misc.error("Failed to copy certificate files: \(error.localizedDescription)")
			throw error
		}
	}
	
	func addToDatabase() async throws {
		
		Storage.shared.addCertificate(
			uuid: _uuid,
			password: _keyPassword,
			nickname: _certNickname,
			ppq: _certPair?.PPQCheck ?? false,
			expiration: _certPair?.ExpirationDate ?? Date(),
			isDefault: _isDefault
		) { _ in
			Logger.misc.info("[\(self._uuid)] Added to database")
		}
	}
	
	private func _directory() async throws -> URL {
		// Documents/Feather/Certificates/\(UUID)
		_fileManager.certificates(_uuid)
	}
}

private enum CertificateFileHandlerError: Error {
	case certNotValid
}
