import Foundation
import CryptoKit
import SwiftPizzaSnips

public enum DirectoryDifferCore {
	private static let comparisonResourceKeys: [URLResourceKey] = [
		.fileSizeKey,
		.creationDateKey,
		.contentModificationDateKey,
		.isDirectoryKey,
	]

	private static let queue = SchedulingQueue<HashDigest>()

	private static let progressLock = NSLock()

	public static func compareFiles(
		between sourceDirectory: URL,
		and destinationDirectory: URL,
		comparingHashes: Bool,
		baseSourceDirectory: URL,
		progress: Progress?
	) async throws -> DiffResults {
		let fm = FileManager.default

		func contentFilter(_ url: URL) throws -> Bool {
			let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
			return values.isSymbolicLink == false
		}

		enum Group {
			case sourceDirectories
			case destinationDirectories
			case sourceFiles
			case destinationFiles
		}

		func toDict(_ urls: [URL]) -> [String: URL] {
			urls.reduce(into: [String: URL]()) {
				$0[$1.lastPathComponent] = $1
			}
		}

		let destinationContents = try fm
			.contentsOfDirectory(
				at: destinationDirectory,
				includingPropertiesForKeys: Self.comparisonResourceKeys)
			.filter(contentFilter)
			.nfurcate {
				guard
					try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory.nilIsFalse
				else { return Group.destinationFiles }

				return .destinationDirectories
			}
		let destinationDirectories = toDict(destinationContents[.destinationDirectories] ?? [])
		let destinationFiles = toDict(destinationContents[.destinationFiles] ?? [])

		let sourceContents = try fm
			.contentsOfDirectory(
				at: sourceDirectory,
				includingPropertiesForKeys: Self.comparisonResourceKeys)
			.filter(contentFilter)
			.nfurcate {
				guard
					try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory.nilIsFalse
				else { return Group.sourceFiles }

				return .sourceDirectories
			}
		let sourceDirectories = toDict(sourceContents[.sourceDirectories] ?? [])
		let sourceFiles = toDict(sourceContents[.sourceFiles] ?? [])

		var out = DiffResults()

		func directoryFilter(_ url: URL) throws -> Bool {
			try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
		}

		let commonDirectories = Set(sourceDirectories.keys)
			.intersection(destinationDirectories.keys)
			.sorted()

		progressLock.withLock {
			progress?.totalUnitCount += commonDirectories.count.asInt64()
		}

		for directory in commonDirectories {
			let newSource = sourceDirectory.appending(component: directory, directoryHint: .isDirectory)
			let newDestination = destinationDirectory.appending(component: directory, directoryHint: .isDirectory)

			let recursiveResults = try await compareFiles(
				between: newSource,
				and: newDestination,
				comparingHashes: comparingHashes,
				baseSourceDirectory: baseSourceDirectory,
				progress: progress)

			out.merge(recursiveResults)
			progressLock.withLock {
				progress?.completedUnitCount += 1
			}
		}

		let currentPath = baseSourceDirectory.relativePathComponents(to: sourceDirectory)
		let sourceOnlyDirectories = Set(sourceDirectories.keys)
			.subtracting(destinationDirectories.keys)
			.sorted()
			.map { currentPath + [$0] }
		out.justSource.append(contentsOf: sourceOnlyDirectories)

		let destinationOnlyDirectories = Set(destinationDirectories.keys)
			.subtracting(sourceDirectories.keys)
			.sorted()
			.map { currentPath + [$0] }
		out.justDestination.append(contentsOf: destinationOnlyDirectories)
		progressLock.withLock {
			let exclusiveDirCount = (sourceOnlyDirectories.count + destinationOnlyDirectories.count).asInt64()
			progress?.totalUnitCount += exclusiveDirCount
			progress?.completedUnitCount += exclusiveDirCount
		}

		let commonFiles = Set(sourceFiles.keys)
			.intersection(destinationFiles.keys)
			.sorted()
		progressLock.withLock {
			progress?.totalUnitCount += commonFiles.count.asInt64()
		}

		let sourceOnlyFiles = Set(sourceFiles.keys)
			.subtracting(commonFiles)
			.sorted()
			.map { currentPath + [$0] }
		out.justSource.append(contentsOf: sourceOnlyFiles)

		let destinationOnlyFiles = Set(destinationFiles.keys)
			.subtracting(commonFiles)
			.sorted()
			.map { currentPath + [$0] }
		out.justDestination.append(contentsOf: destinationOnlyFiles)
		progressLock.withLock {
			let exclusiveFileCount = (sourceOnlyFiles.count + destinationOnlyFiles.count).asInt64()
			progress?.totalUnitCount += exclusiveFileCount
			progress?.completedUnitCount += exclusiveFileCount
		}

		let commonResults = await withTaskGroup(of: DiffResults.Diff.self, returning: DiffResults.self) { group in
			var diffResults = DiffResults()
			for file in commonFiles {
				defer {
					progressLock.withLock {
						progress?.completedUnitCount += 1
					}
				}
				guard
					let sourceURL = sourceFiles[file],
					let destinationURL = destinationFiles[file]
				else {
					diffResults.errored.append(currentPath + [file])
					continue
				}
				guard
					let sourceResourceValues = try? sourceURL.resourceValues(forKeys: Set(Self.comparisonResourceKeys)),
					let destinationResourceValues = try? destinationURL.resourceValues(forKeys: Set(Self.comparisonResourceKeys)),
					let sourceSize = sourceResourceValues.fileSize,
					let sourceCreation = sourceResourceValues.creationDate,
					let sourceModification = sourceResourceValues.contentModificationDate,
					let destinationSize = destinationResourceValues.fileSize,
					let destinationCreation = destinationResourceValues.creationDate,
					let destinationModification = destinationResourceValues.contentModificationDate
				else {
					diffResults.errored.append(currentPath + [file])
					continue
				}

				let diff = DiffResults.Diff(
					path: currentPath + [file],
					creationDate: Duple(source: sourceCreation, destination: destinationCreation),
					modificationDate: Duple(source: sourceModification, destination: destinationModification),
					fileSize: Duple(source: sourceSize, destination: destinationSize),
					hashes: nil)
				guard
					sourceSize == destinationSize,
					sourceCreation == destinationCreation,
					sourceModification == destinationModification
				else {
					diffResults.different.append(diff)
					continue
				}

				guard comparingHashes else {
					diffResults.identical.append(currentPath + [file])
					continue
				}

				group.addTask { [diff] in
					var diff = diff
					async let sourceHash = await queue.addTask(label: "source \(currentPath + [file])") {
						try await Insecure.MD5.hash(sourceURL)
					}
					async let destinationHash = await queue.addTask(label: "destination \(currentPath + [file])") {
						try await Insecure.MD5.hash(destinationURL)
					}

					do {
						try await diff.hashes = Duple(source: sourceHash, destination: destinationHash)
						return diff
					} catch {
						print("Error hashing files for \(currentPath + [file])")
						return diff
					}
				}
			}

			for await diff in group {
				if diff.isMatching == true {
					diffResults.identical.append(diff.path)
				} else {
					diffResults.different.append(diff)
				}
			}
			return diffResults
		}

		return out.merging(commonResults).sorted()
	}
}
