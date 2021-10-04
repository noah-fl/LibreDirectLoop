//
//  LibreDirectViewLoader.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import SwiftUI
import LoopKit
import LoopKitUI

class LibreDirectViewLoader: UINavigationController, CGMManagerOnboarding, CompletionNotifying, UINavigationControllerDelegate {
    let cgmManager: LibreDirectCGMManager?
    let glucoseUnit: DisplayGlucoseUnitObservable?

    weak var cgmManagerOnboardingDelegate: CGMManagerOnboardingDelegate?
    weak var completionDelegate: CompletionDelegate?

    init(cgmManager: LibreDirectCGMManager? = nil, glucoseUnit: DisplayGlucoseUnitObservable? = nil) {
        self.glucoseUnit = glucoseUnit
        self.cgmManager = cgmManager

        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.prefersLargeTitles = true
        delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        let controller = viewController(willShow: (cgmManager == nil ? .setup : .settings))
        setViewControllers([controller], animated: false)
    }

    private enum ControllerType: Int, CaseIterable {
        case setup
        case settings
    }

    private func viewController(willShow view: ControllerType) -> UIViewController {
        guard let cgmManager = cgmManager else {
            fatalError()
        }

        guard let store = cgmManager.store else {
            fatalError()
        }

        let view = LibreDirectView(doneCompletionHandler: { () -> Void in
            self.completionDelegate?.completionNotifyingDidComplete(self)
        }, deleteCompletionHandler: { () -> Void in
                cgmManager.store = nil

                UserDefaults.appGroup.glucoseValues = []
                UserDefaults.appGroup.sensor = nil

                cgmManager.notifyDelegateOfDeletion {
                    DispatchQueue.main.async {
                        self.completionDelegate?.completionNotifyingDidComplete(self)
                    }
                }
            }).environmentObject(store)

        return viewController(rootView: view)
    }

    private func viewController<Content: View>(rootView: Content) -> DismissibleHostingController {
        return DismissibleHostingController(rootView: rootView)
    }
}
