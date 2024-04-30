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
		help: "Source Directory",
		completion: .directory,
		transform: { URL(fileURLWithPath: $0, relativeTo: .currentDirectory()) })
	var sourceDirectory: URL

	@Argument(
		help: "Compared Directory",
		completion: .directory,
		transform: { URL(fileURLWithPath: $0, relativeTo: .currentDirectory()) })
	var destinationDirectory: URL

	@Flag(help: "Compare via hashes - slower than comparing via timestamps and size, but more accurate")
	var compareHashes = false

	mutating func run() async throws {
		print("Comparing original files in \(sourceDirectory.relativePath) to \(destinationDirectory.relativePath)")

		let progress = Progress()
		let tracker = progress.publisher(for: \.fractionCompleted)
			.sink {
				print("\(progress.completedUnitCount) of \(progress.totalUnitCount) - \($0)")
			}
		defer { tracker.cancel() }

		let differences = try await DirectoryDifferCore.compareFiles(
			between: sourceDirectory,
			and: destinationDirectory,
			comparingHashes: compareHashes,
			baseSourceDirectory: sourceDirectory,
			progress: progress)

		print("Identical Items:\n\n")
		for identicalItem in differences.identical {
			print(identicalItem)
		}

		print("Just in source directory:\n\n")
		for sourceItem in differences.justSource {
			print(sourceItem)
		}

		print("Just in destination directory:\n\n")
		for destinationItem in differences.justDestination {
			print(destinationItem)
		}

		print("Differing files:\n\n")
		for differentItem in differences.different {
			print(differentItem)
		}
	}
}
