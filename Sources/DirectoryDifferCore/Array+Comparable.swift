import Foundation

extension Array: Comparable where Element: Comparable {
	public static func < (lhs: Array<Element>, rhs: Array<Element>) -> Bool {
		for (lhsComponent, rhsComponent) in zip(lhs, rhs) {
			guard lhsComponent != rhsComponent else { continue }
			return lhsComponent < rhsComponent
		}
		return lhs.count < rhs.count
	}
}
