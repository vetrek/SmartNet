//
//  
//

import Foundation

struct AnyProgressiveTransferTask: Hashable {
  private let task: any AnyUploadTask
  let start: () -> Void
  var identifier: Int? {
    task.task.taskIdentifier
  }

  init<T: AnyUploadTask>(_ task: T, start: @escaping () -> Void) {
    self.task = task
    self.start = start
  }
  
  static func == (lhs: AnyProgressiveTransferTask, rhs: AnyProgressiveTransferTask) -> Bool {
    lhs.identifier == rhs.identifier
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
}
