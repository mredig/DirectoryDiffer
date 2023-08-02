// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation
import ReplaceWithSymlinksCore

@main
struct ReplaceWithSymlinks: AsyncParsableCommand {
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

	mutating func run() async throws {
		try await ReplaceWithSymlinksCore
			.replaceFiles(
				in: destinationDirectory,
				withFileSymlinksFrom: sourceDirectory,
				compareHashes: compareHashes)
	}
}
