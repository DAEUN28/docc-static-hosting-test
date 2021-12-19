/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class DocumentationDataVariantsTests: XCTestCase {
    func testAccessesVariantWithTrait() throws {
        var variants = DocumentationDataVariants<String>(values: [.swift : "Swift"])
        
        XCTAssertEqual(variants[.swift], "Swift")
        
        let objectiveCTrait = DocumentationDataVariantsTrait(interfaceLanguage: "objc")
        
        XCTAssertNil(variants[objectiveCTrait])
        variants[objectiveCTrait] = "Objective-C"
        XCTAssertEqual(variants[objectiveCTrait], "Objective-C")
    }
    
    func testReturnsDefaultValueInAllValues() throws {
        let variants = DocumentationDataVariants<String>(defaultVariantValue: "Default value")
        XCTAssertEqual(variants.allValues.count, 1)
        let first = try XCTUnwrap(variants.allValues.first)
        XCTAssertEqual(first.trait, .fallback)
        XCTAssertEqual(first.variant, "Default value")
    }
    
    func testSetsDefaultValueWhenTraitIsFallback() throws {
        var variants = DocumentationDataVariants<String>()
        variants[.fallback] = "Default value"
        let first = try XCTUnwrap(variants.allValues.first)
        XCTAssertEqual(first.trait, .fallback)
        XCTAssertEqual(first.variant, "Default value")
    }
    
    func testIsEmpty() throws {
        XCTAssert(DocumentationDataVariants<String>().isEmpty)
        XCTAssertFalse(DocumentationDataVariants<String>(values: [.swift : "Swift"]).isEmpty)
    }
    
    func testHasVariant() throws {
        XCTAssert(DocumentationDataVariants<String>(values: [.swift : "Swift"]).hasVariant(for: .swift))
        XCTAssertFalse(DocumentationDataVariants<String>().hasVariant(for: .swift))
    }
    
    func testSwiftVariantInitializer() throws {
        XCTAssertEqual(DocumentationDataVariants<String>(swiftVariant: "Swift")[.swift], "Swift")
        XCTAssertNil(DocumentationDataVariants<String>(swiftVariant: nil)[.swift])
    }
}
