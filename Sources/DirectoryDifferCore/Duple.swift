import Foundation

public struct Duple<T> {
	let source: T
	let destination: T
}

extension Duple: Comparable where T: Comparable {
	public static func < (lhs: Duple<T>, rhs: Duple<T>) -> Bool {
		guard lhs.source != rhs.source else {
			return lhs.source < rhs.source
		}
		return lhs.destination < rhs.destination
	}
}
extension Duple: Hashable where T: Hashable {}
extension Duple: Equatable where T: Equatable {
	var isMatching: Bool { source == destination }
}
