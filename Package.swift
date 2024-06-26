// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "DirectoryDiffer",
	platforms: [
		.macOS(.v13),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", .upToNextMajor(from: "0.4.5")),
//		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", branch: "0.4.5a"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.executableTarget(
			name: "DirectoryDiffer",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				"DirectoryDifferCore",
			]
		),
		.target(
			name: "DirectoryDifferCore",
			dependencies: [
				"SwiftPizzaSnips",
			]
		)
	]
)
