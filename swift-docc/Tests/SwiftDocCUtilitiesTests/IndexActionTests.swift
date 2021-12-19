/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
@testable import SwiftDocCUtilities
import Markdown

class IndexActionTests: XCTestCase {
    #if !os(iOS)
    func testIndexActionOutputIsDeterministic() throws {
        // Convert a test bundle as input for the IndexAction
        let bundleURL = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let targetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
        defer { try? fileManager.removeItem(at: targetURL) }
        
        let templateURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try Folder.emptyHTMLTemplateDirectory.write(to: templateURL)
        defer { try? fileManager.removeItem(at: templateURL) }
        
        let targetBundleURL = targetURL.appendingPathComponent("Result.builtdocs")
        
        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetBundleURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil
        )
        _ = try action.perform(logHandle: .standardOutput)
        
        let bundleIdentifier = "org.swift.docc.example"
        
        // Repeatedly index the same bundle and verify that the result is the same every time.
        
        var resultIndexDumps = Set<String>()
        
        for iteration in 1...10 {
            let indexURL = targetURL.appendingPathComponent("index_\(iteration)")
            
            let engine = DiagnosticEngine(filterLevel: .warning)
            
            var indexAction = try IndexAction(
                documentationBundleURL: targetBundleURL,
                outputURL: indexURL,
                bundleIdentifier: bundleIdentifier,
                diagnosticEngine: engine
            )
            _ = try indexAction.perform(logHandle: .standardOutput)
            
            let index = try NavigatorIndex(url: indexURL)
            
            resultIndexDumps.insert(index.navigatorTree.root.dumpTree())
            XCTAssertTrue(engine.problems.isEmpty, "Indexing bundle at \(targetURL) resulted in unexpected issues")
        }
        
        // All dumps should be the same, so there should only be one unique index dump
        XCTAssertEqual(resultIndexDumps.count, 1)
    }
    #endif
}
