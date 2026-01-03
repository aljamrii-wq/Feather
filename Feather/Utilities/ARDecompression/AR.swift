//
//  SwiftAR.swift
//  SwiftAR
//
//  Created by nekohaxx on 8/18/24.
//

import Foundation

class AR: NSObject {
	private var _data: Data
	
	init(with url: URL) throws {
		do {
			self._data = try Data(contentsOf: url)
		} catch {
			throw ARError.badArchive("Unable to read archive")
		}
		super.init()
	}
	
	func extract() async throws -> [ARFileModel] {
		guard _data.count >= 8 else {
			throw ARError.badArchive("Invalid header")
		}
		
		let magic = [UInt8](_data.prefix(8))
		if magic != [0x21, 0x3c, 0x61, 0x72, 0x63, 0x68, 0x3e, 0x0a] {
			throw ARError.badArchive("Invalid magic")
		}
		
		let data = _data.subdata(in: 8..<_data.endIndex)
		
		var offset = 0
		var files: [ARFileModel] = []
		while offset < data.count {
			let fileInfo = try _getFileInfo(data, offset)
			files.append(fileInfo)
			offset += fileInfo.size + 60
			offset += offset % 2
		}
		return files
	}
	
	private func _getFileInfo(_ data: Data, _ offset: Int) throws -> ARFileModel {
		guard offset + 60 <= data.count else {
			throw ARError.badArchive("Unexpected end of header")
		}
		
		let sizeString = String(
			data: data.subdata(in: offset+48..<offset+48+10),
			encoding: .ascii
		) ?? ""
		guard
			let size = Int(_removePadding(sizeString)),
			size > 0
		else {
			throw ARError.badArchive("Invalid size")
		}
		
		let nameString = String(
			data: data.subdata(in: offset..<offset+16),
			encoding: .ascii
		) ?? ""
		let name = _removePadding(nameString)
		guard name != "" else {
			throw ARError.badArchive("Invalid name")
		}
		
		guard offset + 60 + size <= data.count else {
			throw ARError.badArchive("Invalid file size")
		}
		
		let modificationString = String(
			data: data.subdata(in: offset+16..<offset+16+12),
			encoding: .ascii
		) ?? ""
		let ownerString = String(
			data: data.subdata(in: offset+28..<offset+28+6),
			encoding: .ascii
		) ?? ""
		let groupString = String(
			data: data.subdata(in: offset+34..<offset+34+6),
			encoding: .ascii
		) ?? ""
		let modeString = String(
			data: data.subdata(in: offset+40..<offset+40+8),
			encoding: .ascii
		) ?? ""
		
		guard
			let modificationTime = Double(_removePadding(modificationString)),
			let ownerId = Int(_removePadding(ownerString)),
			let groupId = Int(_removePadding(groupString)),
			let mode = Int(_removePadding(modeString))
		else {
			throw ARError.badArchive("Invalid metadata")
		}
		
		return ARFileModel(
			name: name,
			modificationDate: Date(timeIntervalSince1970: modificationTime),
			ownerId: ownerId,
			groupId: groupId,
			mode: mode,
			size: size,
			content: data.subdata(in: offset+60..<offset+60+size)
		)
	}
	
	private func _removePadding(_ paddedString: String) -> String {
		guard let data = paddedString.data(using: .utf8) else {
			return ""
		}
		
		guard let firstNonSpaceIndex = data.firstIndex(of: UInt8(ascii: " ")) else {
			return paddedString
		}
		
		let actualData = data[..<firstNonSpaceIndex]
		return String(data: actualData, encoding: .utf8) ?? ""
	}
}

enum ARError: Error {
	case badArchive(String)
}
