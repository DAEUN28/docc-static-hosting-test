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

class AutomaticCurationTests: XCTestCase {
    func testAutomaticTopics() throws {
        // Create each kind of symbol and verify it gets its own topic group automatically
        for kind in AutomaticCuration.groupKindOrder where kind != .module {
            let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:], configureBundle: { url in
                let sidekitURL = url.appendingPathComponent("sidekit.symbols.json")
                let text = try String(contentsOf: sidekitURL)
                    .replacingOccurrences(of: "\"identifier\" : \"swift.enum.case\"", with: "\"identifier\" : \"\(kind.identifier)\"")
                try text.write(to: sidekitURL, atomically: true, encoding: .utf8)
            })
            defer { try? FileManager.default.removeItem(at: url) }

            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
            // Compile docs and verify the generated Topics section
            let symbol = node.semantic as! Symbol
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(symbol) as! RenderNode
            
            XCTAssertNotNil(renderNode.topicSections.first(where: { group -> Bool in
                return group.title == AutomaticCuration.groupTitle(for: kind)
            }), "\(kind.identifier) was not automatically curated in a \(AutomaticCuration.groupTitle(for: kind).singleQuoted) topic group." )
        }
    }

    func testAutomaticTopicsSkippingCustomCuratedSymbols() throws {
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:], configureBundle: { url in
            // Curate some of `SideClass`'s children under SideKit.
            let sideKit = """
            # ``SideKit``
            SideKit framework
            ## Topics
            ### SideKit Basics
            - ``SideClass/path``
            - ``SideClass/url``
            """
            try sideKit.write(to: url.appendingPathComponent("documentation").appendingPathComponent("sidekit.md"), atomically: true, encoding: .utf8)
        })
        defer { try? FileManager.default.removeItem(at: url) }

        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        // Compile the render node to flex the automatic curator
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(symbol) as! RenderNode
        
        // Verify that uncurated element `SideKit/SideClass/Element` is
        // automatically curated in `SideClass`'s "Topics"
        XCTAssertFalse(renderNode.topicSections.filter({ section -> Bool in
            return section.identifiers.contains("doc://org.swift.docc.example/documentation/SideKit/SideClass/Element")
        }).isEmpty)

        // Verify that element `SideKit/SideClass/path` curated in sidecar under `SideKit`
        // is NOT automatically curated in `SideClass`'s "Topics"
        XCTAssertTrue(renderNode.topicSections.filter({ section -> Bool in
            return section.identifiers.contains("doc://org.swift.docc.example/documentation/SideKit/SideClass/path")
        }).isEmpty)
    }

    func testMergingAutomaticTopics() throws {
        let allExpectedChildren = [
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/Element",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/Value(_:)",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/init()",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/myFunction()",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/path",
            "doc://org.swift.docc.example/documentation/SideKit/SideClass/url",
        ]
        
        // Curate one or two of the children at a time and leave the rest for automatic curation.
        let variationsOfChildrenToCurate: [Set<Int>] = allExpectedChildren.indices.flatMap { first in allExpectedChildren.indices.map { second in Set([first, second]) } }
        
        for curatedIndices in variationsOfChildrenToCurate {
            let manualCuration = curatedIndices.map { "- <\(allExpectedChildren[$0])>" }.joined(separator: "\n")
            
            let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
                try """
                # ``SideKit/SideClass``

                Curate some of the children and leave the rest for automatic curation.

                ## Topics
                    
                ### Manually curated

                \(manualCuration)
                """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
            }
            defer { try? FileManager.default.removeItem(at: url) }
            
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
            // Compile docs and verify the generated Topics section
            let symbol = node.semantic as! Symbol
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(symbol) as! RenderNode
            
            // Verify that all the symbols are curated, either manually or automatically
            let curatedSymbols = renderNode.topicSections.flatMap { $0.identifiers }
            XCTAssertEqual(allExpectedChildren.sorted(), curatedSymbols.sorted())
            
            // The manual topic section is listed before any automatic topic sections
            XCTAssertEqual(renderNode.topicSections.first?.title, "Manually curated")
            
            // Check that the automatic topic sections only exist if its elements weren't manually curated
            XCTAssertEqual(
                !curatedIndices.contains(0),
                renderNode.topicSections.contains(where: { $0.title == "Type Aliases" })
            )
            XCTAssertEqual(
                !curatedIndices.contains(1),
                renderNode.topicSections.contains(where: { $0.title == "Enumeration Cases" })
            )
            XCTAssertEqual(
                !curatedIndices.contains(2),
                renderNode.topicSections.contains(where: { $0.title == "Initializers" })
            )
            XCTAssertEqual(
                !curatedIndices.contains(3),
                renderNode.topicSections.contains(where: { $0.title == "Instance Methods" })
            )
            XCTAssertEqual(
                !curatedIndices.contains(4) || !curatedIndices.contains(5),
                renderNode.topicSections.contains(where: { $0.title == "Instance Properties" })
            )
        }
    }
    
    func testSeeAlsoSectionForAutomaticallyCuratedTopics() throws {
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            var graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: url.appendingPathComponent("sidekit.symbols.json")))
            
            // Copy `SideClass` a handful of times
            let sideClassIdentifier = "s:7SideKit0A5ClassC"
            let sideClassSymbol = graph.symbols[sideClassIdentifier]!
            
            for suffix in ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"] {
                // Duplicate the symbol
                var duplicateSymbol = sideClassSymbol
                let newClassName = duplicateSymbol.names.title + suffix
                duplicateSymbol.names.title = newClassName
                duplicateSymbol.identifier.precise = "s:7SideKit0A\(newClassName.count)\(newClassName)C"
                
                // Update the declaration fragment to use the new name
                let declarationFragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment] = [
                    .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: newClassName, preciseIdentifier: nil),
                ]
                let declaration = try JSONDecoder().decode(SymbolGraph.Symbol.DeclarationFragments.self, from: JSONEncoder().encode(declarationFragments))
                duplicateSymbol.mixins[SymbolGraph.Symbol.DeclarationFragments.mixinKey] = declaration
                duplicateSymbol.pathComponents = [newClassName]
                
                graph.symbols[duplicateSymbol.identifier.precise] = duplicateSymbol
                
                // Duplicate all the edges to and from the symbbol
                for relationship in graph.relationships where relationship.source == sideClassIdentifier {
                    var newRelationship = relationship
                    newRelationship.source = duplicateSymbol.identifier.precise
                    graph.relationships.append(newRelationship)
                }
                for relationship in graph.relationships where relationship.target == sideClassIdentifier {
                    var newRelationship = relationship
                    newRelationship.target = duplicateSymbol.identifier.precise
                    graph.relationships.append(newRelationship)
                }
                
                // Add a sidecar file for this symbol
                try """
                # ``SideKit/SideClass\(suffix)``
                
                Curate some of the children and leave the rest for automatic curation.
                
                ## Topics
                
                ### Manually curated
                
                - ``init()``
                - ``path``
                - ``Value(_:)``
                """.write(to: url.appendingPathComponent("documentation/sidekit\(suffix).md"), atomically: true, encoding: .utf8)
            }
            
            let newGraphData = try JSONEncoder().encode(graph)
            try newGraphData.write(to: url.appendingPathComponent("sidekit.symbols.json"))
            
            try """
            # ``SideKit``
            
            Curate the duplicate symbols into different Topic sections and leave some (nr 8, 9, and 10) for automatic curation.
            
            ## Topics
            
            ### First topic
            
            - ``SideClass``
            - ``SideClassOne``
            - ``SideClassTwo``
            
            ### Second topic
            
            - ``SideClassThree``
            - ``SideClassFour``
            - ``SideClassFive``
            
            ### Third topic
            
            - ``SideClassSix``
            - ``SideClassSeven``
            
            """.write(to: url.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``SideKit/SideClass``
            
            Curate some of the children and leave the rest for automatic curation.
            
            ## Topics
            
            ### Manually curated
            
            - ``init()``
            - ``path``
            - ``Value(_:)``

            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: url) }
        
        // The first topic section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // SideKit includes the "Manually curated" task group and additional automatically created groups.
            XCTAssertEqual(renderNode.topicSections.map { $0.title }, ["Manually curated", "Instance Properties", "Instance Methods", "Type Aliases"])
            
            // The other symbols in the same topic section appear in this See Also section
            XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers, [
                "doc://org.swift.docc.example/documentation/SideKit/SideClassOne",
                "doc://org.swift.docc.example/documentation/SideKit/SideClassTwo",
            ])
        }
        
        // The second topic section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassFour", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // The other symbols in the same topic section appear in this See Also section
            XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers, [
                "doc://org.swift.docc.example/documentation/SideKit/SideClassThree",
                "doc://org.swift.docc.example/documentation/SideKit/SideClassFive",
            ])
        }
        
        // The second topic section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassSix", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // The other symbols in the same topic section appear in this See Also section
            XCTAssertEqual(renderNode.seeAlsoSections.first?.identifiers, [
                "doc://org.swift.docc.example/documentation/SideKit/SideClassSeven",
            ])
        }
        
        // The automatically curated symbols shouldn't have a See Also section
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassEight", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassNine", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClassTen", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            XCTAssertNil(renderNode.seeAlsoSections.first, "This symbol was automatically curated and shouldn't have a See Also section")
        }
    }
    
    func testTopLevelSymbolsAreNotAutomaticallyCuratedIfManuallyCuratedElsewhere() throws {
        // A symbol graph that defines symbol hierarchy of:
        //   TestBed -> A
        //           -> B -> C
        // But curation as:
        //   TestBed -> A -> B -> C
        let topLevelCurationSGFURL = Bundle.module.url(
            forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!
        
        // Create a test bundle copy with the symbol graph from above
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:]) { url in
            try? FileManager.default.copyItem(at: topLevelCurationSGFURL, to: url.appendingPathComponent("TopLevelCuration.symbols.json"))
        }
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        do {
            // Get the framework render node
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/TestBed", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // Verify that `B` isn't automatically curated under the framework node
            XCTAssertEqual(
                ["doc://org.swift.docc.example/documentation/TestBed/A"],
                renderNode.topicSections.first?.identifiers
            )
        }
        
        do {
            // Get the `A` render node
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/TestBed/A", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
            
            // Verify that `B` was in fact curated under `A`
            XCTAssertEqual(
                ["doc://org.swift.docc.example/documentation/TestBed/B"],
                renderNode.topicSections.first?.identifiers
            )
        }
    }
    
    func testRelevantLanguagesAreAutoCuratedInMixedLanguageFramework() throws {
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        let (bundle, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        
        let frameworkDocumentationNode = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/MixedLanguageFramework",
                sourceLanguages: [.swift, .objectiveC]
            )
        )
        
        let swiftTopics = try AutomaticCuration.topics(
            for: frameworkDocumentationNode,
            withTrait: .swift,
            context: context
        )
        
        XCTAssertEqual(
            swiftTopics.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.references.map(\.path)
            },
            [
                "Classes",
                "/documentation/MixedLanguageFramework/Bar",
                
                "Structures",
                "/documentation/MixedLanguageFramework/Foo-swift.struct",
                "/documentation/MixedLanguageFramework/SwiftOnlyStruct",
            ]
        )
        
        let objectiveCTopics = try AutomaticCuration.topics(
            for: frameworkDocumentationNode,
            withTrait: DocumentationDataVariantsTrait(interfaceLanguage: "occ"),
            context: context
        )
        
        XCTAssertEqual(
            objectiveCTopics.flatMap { taskGroup in
                [taskGroup.title] + taskGroup.references.map(\.path)
            },
            [
                "Classes",
                "/documentation/MixedLanguageFramework/Bar",
                
                "Variables",
                "/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionNumber",
                "/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionString",
                
                "Type Aliases",
                "/documentation/MixedLanguageFramework/Foo-occ.typealias",
                
                "Enumerations",
                "/documentation/MixedLanguageFramework/Foo-swift.struct",
            ]
        )
    }
}
