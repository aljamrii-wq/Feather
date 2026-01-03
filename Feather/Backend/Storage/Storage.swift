//
//  Persistence.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import CoreData
import OSLog

// MARK: - Class
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer
	
	private let _name: String = "Feather"
	
	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: _name)
		
		if inMemory {
			container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
		}
		
		container.loadPersistentStores(completionHandler: { (storeDescription, error) in
			if let error = error as NSError? {
				fatalError("Unresolved error \(error), \(error.userInfo)")
			}
		})
		
		container.viewContext.automaticallyMergesChangesFromParent = true
		migrateCertificatePasswordsIfNeeded()
	}
	
	var context: NSManagedObjectContext {
		container.viewContext
	}
	
	func saveContext() {
		DispatchQueue.main.async {
			if self.context.hasChanges {
				do {
					try self.context.save()
				} catch {
					OSLog.Logger.storage.error("Failed to save context: \(error.localizedDescription)")
				}
			}
		}
	}
	
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: (request as? NSFetchRequest<NSFetchRequestResult>)!)
		do {
			_ = try context.execute(deleteRequest)
		} catch {
			OSLog.Logger.storage.error("Failed to clear context: \(error.localizedDescription)")
		}
	}
	
	func countContent<T: NSManagedObject>(for type: T.Type) -> String {
		let request = T.fetchRequest()
		return "\((try? context.count(for: request)) ?? 0)"
	}
}
