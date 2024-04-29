// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation
import DirectoryDifferCore

@main
struct DirectoryDiffer: AsyncParsableCommand {
	@Argument(
		help: "The directory the original files are in",
		completion: .directory,
		transform: { URL(fileURLWithPath: $0, relativeTo: .currentDirectory()) })
	var sourceDirectory: URL

	@Argument(
		help: "The directory with duplicated files that should get replaced with symlinks",
		completion: .directory,
		transform: { URL(fileURLWithPath: $0, relativeTo: .currentDirectory()) })
	var destinationDirectory: URL

	@Flag(help: "Compare hashes")
	var compareHashes = false

	@Flag(help: "Dry run - don't actually make changes")
	var dryRun = false

	mutating func run() async throws {
		if dryRun {
			print("Dry run. No changes will be made...")
		}

		print("Comparing original files in \(sourceDirectory.relativePath) to potential duplicates in \(destinationDirectory.relativePath)")

		try await DirectoryDifferCore
			.replaceFiles(
				in: destinationDirectory,
				withFileSymlinksFrom: sourceDirectory,
				commit: !dryRun,
				compareHashes: compareHashes)
	}
}
