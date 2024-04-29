import Foundation

public extension URL {
	func relativePathComponents(to url: URL) -> [String] {
		let thisPathComponents: [String]
		if hasDirectoryPath {
			thisPathComponents = pathComponents
		} else {
			thisPathComponents = deletingLastPathComponent().pathComponents
		}
		let destPathComponents = url.pathComponents

		var divergeIndex = 0
		for (index, component) in thisPathComponents.enumerated() {
			divergeIndex = index
			guard
				index < destPathComponents.count
			else { break }
			let destComponent = destPathComponents[index]

			guard destComponent == component else { break }
		}

		let upDir = ".."

		let sourcePath = thisPathComponents[divergeIndex...]
		let destPath = destPathComponents[divergeIndex...]

		var outPath = Array(repeating: upDir, count: sourcePath.count)
		outPath.append(contentsOf: destPath)

		return outPath
	}

	func relativePath(to url: URL) -> String {
		relativePathComponents(to: url).joined(separator: "/")
	}
}
