import Foundation
import CryptoKit

extension HashFunction {
	static func hash(_ url: URL) async throws -> Self.Digest {
		let fh = try FileHandle(forReadingFrom: url)
		var hash = Self.init()

		let bufferSize = 40960
		var buffer = Data(capacity: bufferSize)
		for try await byte in fh.bytes {
			buffer.append(byte)

			if buffer.count >= bufferSize {
				hash.update(data: buffer)
				buffer = Data(capacity: bufferSize)
			}
		}

		if buffer.isEmpty == false {
			hash.update(data: buffer)
		}

		return hash.finalize()
	}
}
