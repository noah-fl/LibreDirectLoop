//
//  LibreDirectPlugin.swift
//  LibreDirectPlugin
//
//  Created by Nathaniel Hamming on 2019-12-19.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import os.log
import LoopKitUI
import LibreDirect

class LibreDirectPlugin: NSObject, CGMManagerUIPlugin {    
    public var cgmManagerType: CGMManagerUI.Type? {
        return LibreDirectCGMManager.self
    }
    
    override init() {
        super.init()
    }
}
