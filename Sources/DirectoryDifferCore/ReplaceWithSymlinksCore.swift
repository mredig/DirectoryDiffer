import Foundation
import CryptoKit
import SwiftPizzaSnips

public enum DirectoryDifferCore {
	public static func replaceFiles(
		in destinationDirectory: URL,
		withFileSymlinksFrom sourceDirectory: URL,
		commit: Bool,
		compareHashes: Bool) async throws {

			let fm = FileManager.default

			func contentFilter(_ url: URL) throws -> Bool {
				let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
				return values.isSymbolicLink == false
			}

			let destinationContents = try fm
				.contentsOfDirectory(
					at: destinationDirectory,
					includingPropertiesForKeys: [
						.isSymbolicLinkKey,
						.isDirectoryKey
					])
				.filter(contentFilter)

			let sourceContents = try fm
				.contentsOfDirectory(
					at: sourceDirectory,
					includingPropertiesForKeys: [
						.isSymbolicLinkKey,
						.isDirectoryKey
					])
				.filter(contentFilter)

			let dups = try await duplicates(
				betweenSourceContent: sourceContents,
				andDestinationContent: destinationContents,
				comparingHashes: compareHashes)
			print("matches: ")
			dups.forEach { print($0.lastPathComponent) }

			guard commit else { return }

			for dup in dups {
				let destinationFileURL = destinationDirectory.appending(component: "\(dup.lastPathComponent)", directoryHint: .notDirectory)
				try fm.trashItem(at: destinationFileURL, resultingItemURL: nil)
				let url = URL(string: destinationFileURL.relativePath(to: dup).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)!
				try fm.createSymbolicLink(at: destinationFileURL, withDestinationURL: url)
			}
		}

	private static func duplicates(
		betweenSourceContent sourceContents: [URL],
		andDestinationContent destinationContent: [URL],
		comparingHashes: Bool) async throws -> [URL] {

			func key(_ keyValue: String) -> String {
				comparingHashes ? keyValue.lowercased() : keyValue
			}

			let destinationNames = destinationContent.reduce(into: [String: URL](), {
				$0[key($1.lastPathComponent)] = $1
			})
			let matches = sourceContents.filter { destinationNames[key($0.lastPathComponent)] != nil }

			guard comparingHashes else { return matches }

			let hashMatches = try await withThrowingTaskGroup(of: URL?.self) { group in
				let queue = SchedulingQueue<URL?>()
				for (index, sourceURL) in matches.enumerated() {
					guard let destinationURL = destinationNames[key(sourceURL.lastPathComponent)] else { continue }
					group.addTask {
						return try await queue.addTask(label: "\(index): \(sourceURL.lastPathComponent)") {
							print("Comparing files named \(sourceURL.lastPathComponent)...")
							let sourceIsDirectory = try sourceURL.resourceValues(forKeys: [.isDirectoryKey])
							let destinationIsDirectory = try destinationURL.resourceValues(forKeys: [.isDirectoryKey])
							if
								sourceIsDirectory.isDirectory.nilIsFalse == true,
								destinationIsDirectory.isDirectory.nilIsFalse == true {

								print("\(sourceURL.lastPathComponent) match!")
								return sourceURL
							} else if sourceIsDirectory.isDirectory.nilIsFalse != destinationIsDirectory.isDirectory.nilIsFalse {

								print("Directory/file mismatch: \(sourceURL)")
								return nil
							}

							async let sourceHash = Insecure.MD5.hash(sourceURL)
							async let destinationHash = Insecure.MD5.hash(destinationURL)

							guard try await sourceHash == (try await destinationHash) else { return nil }
							print("\(sourceURL.lastPathComponent) match!")
							return sourceURL
						}
					}
				}

				var matchingURLs: [URL] = []
				for try await matchingURL in group {
					guard let matchingURL else { continue }
					matchingURLs.append(matchingURL)
				}
				return matchingURLs
			}
			print()

			return hashMatches
		}
}
