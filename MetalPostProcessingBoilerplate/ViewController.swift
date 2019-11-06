//
//  MyViewController.swift
//  metalfromscratch
//
//  Created by Oskar on 2019-10-25.
//  Copyright © 2019 Shortcut Labs AB. All rights reserved.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

	var mtkView: MTKView!
	var device: MTLDevice!
	var renderer: Renderer!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		mtkView = self.view as? MTKView
		device = MTLCreateSystemDefaultDevice()
		mtkView.device = device
		
		renderer = Renderer(mtkView: self.mtkView)
		renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
		
		mtkView.delegate = self.renderer
	}
}
