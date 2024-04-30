import Foundation

public struct DiffResults {
	public internal(set) var identical: [[String]] = []
	public internal(set) var justSource: [[String]] = []
	public internal(set) var justDestination: [[String]] = []
	public internal(set) var different: [Diff] = []
	public internal(set) var errored: [[String]] = []

	public mutating func merge(_ other: DiffResults) {
		identical.append(contentsOf: other.identical)
		justSource.append(contentsOf: other.justSource)
		justDestination.append(contentsOf: other.justDestination)
		different.append(contentsOf: other.different)
		errored.append(contentsOf: other.errored)
	}

	public func merging(_ other: DiffResults) -> DiffResults {
		var new = self
		new.merge(other)
		return new
	}

	public mutating func sort() {
		identical.sort()
		justSource.sort()
		justDestination.sort()
		different.sort()
		errored.sort()
	}

	public func sorted() -> DiffResults {
		var new = self
		new.sort()
		return new
	}

	public struct Diff: Comparable, Hashable, Equatable, CustomStringConvertible {
		private static let dateFormatter = DateFormatter().with {
			$0.timeStyle = .short
			$0.dateStyle = .short
		}

		private static let byteFormatter = ByteCountFormatter().with {
			$0.countStyle = .file
			$0.includesActualByteCount = true
		}

		public let path: [String]
		public let creationDate: Duple<Date>
		public let modificationDate: Duple<Date>
		public let fileSize: Duple<Int>
		public internal(set) var hashes: Duple<HashDigest>?

		public static func < (lhs: Diff, rhs: Diff) -> Bool {
			lhs.path < rhs.path
		}

		public var description: String {
			var out = "file: \(path.joined(separator: "/"))"

			if creationDate.isMatching == false {
				out += "\ncreation (source): \(Self.dateFormatter.string(from: creationDate.source))"
				out += "\ncreation (destination): \(Self.dateFormatter.string(from: creationDate.destination))"
			}
			if modificationDate.isMatching == false {
				out += "\nmodification (source): \(Self.dateFormatter.string(from: modificationDate.source))"
				out += "\nmodification (destination): \(Self.dateFormatter.string(from: modificationDate.destination))"
			}
			if fileSize.isMatching == false {
				out += "\nfile size (source): \(Self.byteFormatter.string(fromByteCount: fileSize.source.asInt64()))"
				out += "\nfile size (destination): \(Self.byteFormatter.string(fromByteCount: fileSize.destination.asInt64()))"
			}
			if let hashes, hashes.isMatching == false {
				out += "\nhash (source): \(hashes.source.toHexString())"
				out += "\nhash (destination): \(hashes.destination.toHexString())"
			}

			return out
		}
	}
}
