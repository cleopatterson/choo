import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        Task { @MainActor in
            let sharedText = await extractSharedText()
            let hostingController = UIHostingController(
                rootView: ShareFormView(
                    initialText: sharedText,
                    onSave: { [weak self] title, content in
                        PendingShareManager.addPendingNote(title: title, content: content)
                        self?.extensionContext?.completeRequest(returningItems: nil)
                    },
                    onCancel: { [weak self] in
                        self?.extensionContext?.cancelRequest(withError: NSError(
                            domain: "com.tonywall.wallboard.share",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "User cancelled"]
                        ))
                    }
                )
            )

            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            hostingController.didMove(toParent: self)
        }
    }

    private func extractSharedText() async -> String {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return "" }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    if let item = try? await provider.loadItem(forTypeIdentifier: "public.plain-text"),
                       let text = item as? String, !text.isEmpty {
                        return text
                    }
                }
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    if let item = try? await provider.loadItem(forTypeIdentifier: "public.url"),
                       let url = item as? URL {
                        return url.absoluteString
                    }
                }
            }
        }
        return ""
    }
}
