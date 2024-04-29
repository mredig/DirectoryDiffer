import Foundation

/// FIFO is not guaranteed - it will USUALLY be FIFO, but sometimes something will get hung up
actor SchedulingQueue<T> {
	var maxConcurrentTasks = ProcessInfo.processInfo.processorCount

	private(set) var tasks: Set<Task<T, Error>> = []

	private var waitingQueue: [CheckedContinuation<Void, Never>] = []

	func addTask(label: String? = nil, _ block: @escaping () async throws -> T) async throws -> T {
		do {
			return try await _addTask(label: label, block)
		} catch SchedulingQueueError.queueFull {
			await withCheckedContinuation { continuation in
				waitingQueue.append(continuation)
			}
			return try await addTask(label: label, block)
		}
	}

	private func _addTask(label: String? = nil, _ block: @escaping () async throws -> T) async throws -> T {
		guard tasks.count < maxConcurrentTasks else { throw SchedulingQueueError.queueFull }

		let newTask = Task {
			let result = try await block()
			return result
		}
		tasks.insert(newTask)

		let result = await newTask.result
		tasks.remove(newTask)
		bumpQueue()
		return try result.get()
	}

	private func bumpQueue() {
		guard
			let continuation = waitingQueue.first
		else { return }

		waitingQueue.removeFirst()
		continuation.resume()
	}

	enum SchedulingQueueError: Error {
		case queueFull
	}
}
