/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class RenderNodeCodableTests: XCTestCase {
    
    var bareRenderNode = RenderNode(
        identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
        kind: .article
    )
    
    var testVariantOverride = VariantOverride(
        traits: [.interfaceLanguage("objc")],
        patch: [
            .replace(pointer: JSONPointer(pathComponents: ["foo"]), encodableValue: "bar"),
        ]
    )
    
    func testDataCorrupted() {
        XCTAssertThrowsError(try RenderNode.decode(fromJSON: corruptedJSON), "RenderNode decode didn't throw as expected.") { error in
            XCTAssertTrue(error is RenderNode.CodingError)
            let description = error.localizedDescription
            XCTAssertTrue(description.contains("The given data was not valid JSON."))
        }
    }
    
    func testMissingKeyError() {
        do {
            let renderNode = try RenderNode.decode(fromJSON: emptyJSON)
            XCTAssertNotNil(renderNode)
        } catch {
            XCTAssertTrue(error is RenderNode.CodingError, "Error thrown is not a coding error")
            let description = error.localizedDescription
            XCTAssertTrue(description.contains("No value associated with key"), "Incorrect error message")
            // Ensure the information about the missing key is there.
            XCTAssertTrue(description.contains("schemaVersion"), "Missing key name in error description")
        }
    }
    
    func testTypeMismatchError() {
        do {
            let renderNode = try RenderNode.decode(fromJSON: typeMismatch)
            XCTAssertNotNil(renderNode)
        } catch {
            XCTAssertTrue(error is RenderNode.CodingError)
            let description = error.localizedDescription
            XCTAssertTrue(
                // Leave out the end of the message to account for slight differences between platforms.
                description.contains("Expected to decode Int")
            )
            // Ensure the information about the mismatch key is there.
            XCTAssertTrue(description.contains("schemaVersion"))
        }
    }
    
    func testPrettyPrintByDefaultOff() {
        let renderNode = bareRenderNode
        do {
            let encodedData = try renderNode.encodeToJSON()
            let jsonString = String(data: encodedData, encoding: .utf8)!
            XCTAssertFalse(jsonString.contains("\r\n"))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testPrettyPrintedEncoder() {
        let renderNode = bareRenderNode
        do {
            // No pretty print
            let encoder = RenderJSONEncoder.makeEncoder(prettyPrint: false)
            let encodedData = try renderNode.encodeToJSON(with: encoder)
            let jsonString = String(data: encodedData, encoding: .utf8)!
            XCTAssertFalse(jsonString.contains("\n  "))
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            // Yes pretty print
            let encoder = RenderJSONEncoder.makeEncoder(prettyPrint: true)
            let encodedData = try renderNode.encodeToJSON(with: encoder)
            let jsonString = String(data: encodedData, encoding: .utf8)!
            XCTAssertTrue(jsonString.contains("\n  "))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testEncodesVariantOverridesSetAsProperty() throws {
        var renderNode = bareRenderNode
        renderNode.variantOverrides = VariantOverrides(values: [testVariantOverride])
        
        let decodedNode = try encodeAndDecode(renderNode)
        try assertVariantOverrides(XCTUnwrap(decodedNode.variantOverrides))
    }
    
    func testEncodesVariantOverridesAccumulatedInEncoder() throws {
        let encoder = RenderJSONEncoder.makeEncoder()
        (encoder.userInfo[.variantOverrides] as! VariantOverrides).add(testVariantOverride)
        
        let decodedNode = try encodeAndDecode(bareRenderNode, encoder: encoder)
        try assertVariantOverrides(XCTUnwrap(decodedNode.variantOverrides))
    }
    
    func testDoesNotEncodeVariantOverridesIfEmpty() throws {
        let encoder = RenderJSONEncoder.makeEncoder()
        
        // Don't record any overrides.
        
        let decodedNode = try encodeAndDecode(bareRenderNode, encoder: encoder)
        XCTAssertNil(decodedNode.variantOverrides)
    }
    
    private func assertVariantOverrides(_ variantOverrides: VariantOverrides) throws {
        XCTAssertEqual(variantOverrides.values.count, 1)
        let variantOverride = try XCTUnwrap(variantOverrides.values.first)
        XCTAssertEqual(variantOverride.traits, testVariantOverride.traits)
        
        XCTAssertEqual(variantOverride.patch.count, 1)
        let operation = try XCTUnwrap(variantOverride.patch.first)
        XCTAssertEqual(operation.operation, testVariantOverride.patch[0].operation)
        XCTAssertEqual(operation.pointer.pathComponents, testVariantOverride.patch[0].pointer.pathComponents)
    }
    
    private func encodeAndDecode<Value: Codable>(_ value: Value, encoder: JSONEncoder = .init()) throws -> Value {
        try JSONDecoder().decode(Value.self, from: encoder.encode(value))
    }
}

fileprivate let corruptedJSON = Data("{{}".utf8)
fileprivate let emptyJSON = Data("{}".utf8)
fileprivate let typeMismatch = Data("""
{"schemaVersion":{"major":"type mismatch","minor":0,"patch":0}}
""".utf8)
