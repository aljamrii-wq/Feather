//
//  ZsignHandler.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import Foundation
import ZsignSwift
import UIKit

final class ZsignHandler {
	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
	}
	
	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty else {
			return
		}
		
		let bundle = Bundle(url: _appUrl)
		let execURL = _appUrl.appendingPathComponent(bundle?.exec ?? "")
		
		try Zsign.removeDylibs(at: execURL, dylibs: _options.disInjectionFiles)
	}
	
	func sign() async throws {
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}

		try await Zsign.sign(
			appURL: _appUrl,
			provisioningURL: Storage.shared.getFile(.provision, from: cert),
			p12URL: Storage.shared.getFile(.certificate, from: cert),
			p12Password: Storage.shared.password(for: cert) ?? "",
			entitlementsURL: _options.appEntitlementsFile,
			removeProvision: !_options.removeProvisioning
		)
	}
	
	func adhocSign() async throws {
		try await Zsign.sign(
			appURL: _appUrl,
			entitlementsURL: _options.appEntitlementsFile,
			adhoc: true,
			removeProvision: !_options.removeProvisioning
		)
	}
}
