//
//  Decompression.swift
//  feather
//
//  Created by samara on 21.08.2024.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import Foundation
import SWCompression
import Compression
import OSLog

private func _safeArchivePath(base: URL, entryName: String) -> URL? {
	let trimmed = entryName.trimmingCharacters(in: .whitespacesAndNewlines)
	guard !trimmed.isEmpty else { return nil }
	
	let candidate = URL(fileURLWithPath: trimmed, relativeTo: base).standardizedFileURL
	let basePath = base.standardizedFileURL.path
	
	guard candidate.path.hasPrefix(basePath + "/") else {
		return nil
	}
	
	return candidate
}

func extractFile(at fileURL: inout URL) throws {
	let fileExtension = fileURL.pathExtension.lowercased()
	let fileManager = FileManager.default
	
	let decompressors: [String: (Data) throws -> Data] = [
		"xz": XZArchive.unarchive,
		"lzma": LZMA.decompress,
		"bz2": BZip2.decompress,
		"gz": GzipArchive.unarchive
	]
	
	if let decompressor = decompressors[fileExtension] {
		let outputURL = fileURL.deletingPathExtension()
		try decompressor(Data(contentsOf: fileURL)).write(to: outputURL)
		fileURL = outputURL
		return
	}
	
	if fileExtension == "tar" {
		let tarData = try Data(contentsOf: fileURL)
		let tarContainer = try TarContainer.open(container: tarData)
		
		let extractionDirectory = fileURL.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
		try fileManager.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
		
		for entry in tarContainer {
			guard let entryPath = _safeArchivePath(base: extractionDirectory, entryName: entry.info.name) else {
				Logger.misc.warning("Skipped unsafe tar entry: \(entry.info.name)")
				continue
			}
			
			if entry.info.type == .directory {
				try fileManager.createDirectory(at: entryPath, withIntermediateDirectories: true)
			} else if entry.info.type == .regular, let entryData = entry.data {
				try fileManager.createDirectory(
					at: entryPath.deletingLastPathComponent(),
					withIntermediateDirectories: true
				)
				try entryData.write(to: entryPath)
			}
		}
		
		fileURL = extractionDirectory
		return
	}
	
	throw TweakHandlerError.unsupportedFileExtension(fileExtension)
}
