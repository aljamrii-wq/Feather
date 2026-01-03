//
//  SigningValidation.swift
//  Feather
//
//  Created by Codex.
//

import Foundation

struct SigningValidation {
	struct Result {
		let effectiveBundleId: String?
		let warnings: [String]
	}
	
	static func validate(
		app: AppInfoPresentable,
		options: Options,
		certificate: CertificatePair?
	) -> Result {
		let effectiveBundleId = options.appIdentifier ?? app.identifier
		var warnings: [String] = []
		
		if let bundleId = effectiveBundleId, bundleId.isEmpty {
			warnings.append(.localized("Bundle identifier is empty."))
		}
		
		if
			let cert = certificate,
			let profile = Storage.shared.getProvisionFileDecoded(for: cert)
		{
			let entitlements = profile.Entitlements ?? [:]
			if let appId = entitlements["application-identifier"]?.value as? String {
				if let bundleId = effectiveBundleId, !_matchesApplicationIdentifier(appId, bundleId: bundleId) {
					warnings.append(.localized("Provisioning profile app ID does not match the target bundle ID."))
				}
			} else if effectiveBundleId != nil {
				warnings.append(.localized("Provisioning profile does not declare application-identifier."))
			}
			
			if let teamIds = profile.TeamIdentifier.first {
				if let appId = entitlements["application-identifier"]?.value as? String, !appId.hasPrefix(teamIds + ".") {
					warnings.append(.localized("Provisioning profile team identifier does not match application-identifier."))
				}
			}
		}
		
		if let entitlementsURL = options.appEntitlementsFile {
			if let custom = _loadEntitlements(from: entitlementsURL) {
				if let appId = custom["application-identifier"] as? String {
					if let bundleId = effectiveBundleId, !_matchesApplicationIdentifier(appId, bundleId: bundleId) {
						warnings.append(.localized("Custom entitlements application-identifier does not match the target bundle ID."))
					}
				} else {
					warnings.append(.localized("Custom entitlements do not declare application-identifier."))
				}
			} else {
				warnings.append(.localized("Unable to read custom entitlements file."))
			}
		}
		
		return Result(effectiveBundleId: effectiveBundleId, warnings: warnings)
	}
	
	private static func _loadEntitlements(from url: URL) -> [String: Any]? {
		NSDictionary(contentsOf: url) as? [String: Any]
	}
	
	private static func _matchesApplicationIdentifier(_ applicationId: String, bundleId: String) -> Bool {
		guard let dotIndex = applicationId.firstIndex(of: ".") else {
			return false
		}
		
		let suffix = String(applicationId[applicationId.index(after: dotIndex)...])
		
		if suffix == "*" {
			return true
		}
		
		if suffix.contains("*") {
			let pattern = "^" + NSRegularExpression.escapedPattern(for: suffix)
				.replacingOccurrences(of: "\\*", with: ".*") + "$"
			let regex = try? NSRegularExpression(pattern: pattern)
			let range = NSRange(location: 0, length: bundleId.utf16.count)
			return regex?.firstMatch(in: bundleId, options: [], range: range) != nil
		}
		
		return suffix == bundleId
	}
}
