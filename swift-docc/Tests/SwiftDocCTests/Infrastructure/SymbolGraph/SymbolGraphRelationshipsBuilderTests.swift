/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SymbolKit
@testable import SwiftDocC

class SymbolGraphRelationshipsBuilderTests: XCTestCase {
    
    private func createSymbols(in symbolIndex: inout [String: DocumentationNode], bundle: DocumentationBundle, sourceType: SymbolGraph.Symbol.Kind, targetType: SymbolGraph.Symbol.Kind) -> SymbolGraph.Relationship {
        let sourceIdentifier = SymbolGraph.Symbol.Identifier(precise: "A", interfaceLanguage: SourceLanguage.swift.id)
        let targetIdentifier = SymbolGraph.Symbol.Identifier(precise: "B", interfaceLanguage: SourceLanguage.swift.id)
        
        let sourceRef = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/A", sourceLanguage: .swift)
        let targetRef = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/B", sourceLanguage: .swift)
        
        let sourceSymbol = SymbolGraph.Symbol(identifier: sourceIdentifier, names: SymbolGraph.Symbol.Names(title: "A", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["MyKit", "A"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .class, displayName: "Class"), mixins: [:])
        let targetSymbol = SymbolGraph.Symbol(identifier: targetIdentifier, names: SymbolGraph.Symbol.Names(title: "B", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["MyKit", "B"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .class, displayName: "Protocol"), mixins: [:])
        
        let engine = DiagnosticEngine()
        symbolIndex["A"] = DocumentationNode(reference: sourceRef, symbol: sourceSymbol, platformName: "macOS", moduleName: "MyKit", article: nil, engine: engine)
        symbolIndex["B"] = DocumentationNode(reference: targetRef, symbol: targetSymbol, platformName: "macOS", moduleName: "MyKit", article: nil, engine: engine)
        XCTAssert(engine.problems.isEmpty)
        
        return SymbolGraph.Relationship(source: sourceIdentifier.precise, target: targetIdentifier.precise, kind: .defaultImplementationOf, targetFallback: nil)
    }
    
    func testImplementsRelationship() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var symbolIndex = [String: DocumentationNode]()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(in: &symbolIndex, bundle: bundle, sourceType: .init(parsedIdentifier: .class, displayName: "Class"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addImplementationRelationship(edge: edge, in: bundle, context: context, symbolIndex: &symbolIndex, engine: engine)
        
        // Test default implementation was added
        XCTAssertFalse((symbolIndex["B"]!.semantic as! Symbol).defaultImplementations.implementations.isEmpty)
    }

    func testConformsRelationship() throws {
        let bundle = try testBundle(named: "TestBundle")
        var symbolIndex = [String: DocumentationNode]()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(in: &symbolIndex, bundle: bundle, sourceType: .init(parsedIdentifier: .class, displayName: "Class"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addConformanceRelationship(edge: edge, in: bundle, symbolIndex: &symbolIndex, engine: engine)
        
        // Test default conforms to was added
        guard let conformsTo = (symbolIndex["A"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.conformsTo
        }) else {
            XCTFail("Conforms to group not added")
            return
        }
        XCTAssertEqual(conformsTo.destinations.first?.url?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/B")
        
        // Test default conformance was added
        guard let conforming = (symbolIndex["B"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.conformingTypes
        }) else {
            XCTFail("Conforming types not added")
            return
        }
        XCTAssertEqual(conforming.destinations.first?.url?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/A")
    }

    func testInheritanceRelationship() throws {
        let bundle = try testBundle(named: "TestBundle")
        var symbolIndex = [String: DocumentationNode]()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(in: &symbolIndex, bundle: bundle, sourceType: .init(parsedIdentifier: .class, displayName: "Class"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addInheritanceRelationship(edge: edge, in: bundle, symbolIndex: &symbolIndex, engine: engine)
        
        // Test inherits was added
        guard let inherits = (symbolIndex["A"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.inheritsFrom
        }) else {
            XCTFail("Inherits from not added")
            return
        }
        XCTAssertEqual(inherits.destinations.first?.url?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/B")
        
        // Test decendants were added
        guard let inherited = (symbolIndex["B"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.inheritedBy
        }) else {
            XCTFail("Inherited by types not added")
            return
        }
        XCTAssertEqual(inherited.destinations.first?.url?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/A")
    }
    
    func testRequirementRelationship() throws {
        let bundle = try testBundle(named: "TestBundle")
        var symbolIndex = [String: DocumentationNode]()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(in: &symbolIndex, bundle: bundle, sourceType: .init(parsedIdentifier: .class, displayName: "Class"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addRequirementRelationship(edge: edge, in: bundle, symbolIndex: &symbolIndex, engine: engine)
        
        // Test default implementation was added
        XCTAssertTrue((symbolIndex["A"]!.semantic as! Symbol).isRequired)
    }
}
