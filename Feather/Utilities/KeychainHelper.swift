//
//  KeychainHelper.swift
//  Feather
//
//  Created by Codex.
//

import Foundation
import Security

enum KeychainHelper {
	enum KeychainError: Error {
		case unexpectedStatus(OSStatus)
	}
	
	private static var service: String {
		Bundle.main.bundleIdentifier ?? "Feather"
	}
	
	static func setPassword(_ password: String, for uuid: String) throws {
		let data = Data(password.utf8)
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: uuid,
			kSecValueData as String: data,
			kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
		]
		
		let status = SecItemAdd(query as CFDictionary, nil)
		if status == errSecDuplicateItem {
			let updateQuery: [String: Any] = [
				kSecClass as String: kSecClassGenericPassword,
				kSecAttrService as String: service,
				kSecAttrAccount as String: uuid
			]
			let attributes: [String: Any] = [
				kSecValueData as String: data
			]
			let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
			if updateStatus != errSecSuccess {
				throw KeychainError.unexpectedStatus(updateStatus)
			}
			return
		}
		
		if status != errSecSuccess {
			throw KeychainError.unexpectedStatus(status)
		}
	}
	
	static func password(for uuid: String) -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: uuid,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		
		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		guard status == errSecSuccess, let data = item as? Data else {
			return nil
		}
		
		return String(data: data, encoding: .utf8)
	}
	
	static func deletePassword(for uuid: String) {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: uuid
		]
		
		SecItemDelete(query as CFDictionary)
	}
}
