//
//  
//

import Foundation

struct AnyProgressiveTransferTask: Hashable {
  private let task: any AnyUploadTask
  var identifier: Int? {
    task.task.taskIdentifier
  }
  
  init<T: AnyUploadTask>(_ task: T) {
    self.task = task
  }
  
  static func == (lhs: AnyProgressiveTransferTask, rhs: AnyProgressiveTransferTask) -> Bool {
    lhs.identifier == rhs.identifier
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
}
