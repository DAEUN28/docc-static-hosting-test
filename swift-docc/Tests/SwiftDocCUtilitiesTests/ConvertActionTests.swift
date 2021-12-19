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

class ConvertActionTests: XCTestCase {
    #if !os(iOS)
    let imageFile = Bundle.module.url(
        forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        .appendingPathComponent("figure1.png")
    
    let symbolGraphFile = Bundle.module.url(
        forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        .appendingPathComponent("FillIntroduced.symbols.json")
    
    let objectiveCSymbolGraphFile = Bundle.module.url(
        forResource: "DeckKit-Objective-C",
        withExtension: "symbols.json",
        subdirectory: "Test Resources"
    )!
    
    /// A symbol graph file that has missing symbols.
    let incompleteSymbolGraphFile = TextFile(name: "TechnologyX.symbols.json", utf8Content: """
        {
          "metadata": {
              "formatVersion" : {
                  "major" : 1
              },
              "generator" : "app/1.0"
          },
          "module" : {
            "name" : "MyKit",
            "platform" : {
              "architecture" : "x86_64",
              "vendor" : "apple",
              "operatingSystem" : {
                "name" : "ios",
                "minimumVersion" : {
                  "major" : 13,
                  "minor" : 0,
                  "patch" : 0
                }
              }
            }
          },
          "symbols" : [],
          "relationships" : [
            {
              "source" : "s:5MyKit0A5ProtocolP",
              "target" : "s:5Foundation0A5EarhartP",
              "kind" : "conformsTo"
            }
          ]
        }
        """
    )
    
    func testCopyingImageAssets() throws {
        XCTAssert(FileManager.default.fileExists(atPath: imageFile.path))
        let testImageName = "TestImage.png"
        
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: imageFile, newName: testImageName),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "images", content: [
               CopyOfFile(original: imageFile, newName: testImageName),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
        
        // Verify that the copied image has the same capitalization as the original
        let copiedImageOutput = testDataProvider.files.keys
            .filter({ $0.hasPrefix(result.outputs[0].appendingPathComponent("images").path + "/") })
            .map({ $0.replacingOccurrences(of: result.outputs[0].appendingPathComponent("images").path + "/", with: "") })
        
        XCTAssertEqual(copiedImageOutput, [testImageName])
    }
    
    func testCopyingVideoAssets() throws {
        let videoFile = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                .appendingPathComponent("introvideo.mp4")
        
        XCTAssert(FileManager.default.fileExists(atPath: videoFile.path))
        let testVideoName = "TestVideo.mp4"
        
        // Documentation bundle that contains a video
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: videoFile, newName: testVideoName),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "videos", content: [
               CopyOfFile(original: videoFile, newName: testVideoName),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
        
        // Verify that the copied video has the same capitalization as the original
        let copiedVideoOutput = testDataProvider.files.keys
            .filter({ $0.hasPrefix(result.outputs[0].appendingPathComponent("videos").path + "/") })
            .map({ $0.replacingOccurrences(of: result.outputs[0].appendingPathComponent("videos").path + "/", with: "") })
        
        XCTAssertEqual(copiedVideoOutput, [testVideoName])
    }
    
    // Ensures we don't regress on copying download assets to the build folder (72599615)
    func testCopyingDownloadAssets() throws {
        let downloadFile = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                .appendingPathComponent("project.zip")
        
        let tutorialFile = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                .appendingPathComponent("TestTutorial.tutorial")
        
        let tutorialOverviewFile = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                .appendingPathComponent("TestOverview.tutorial")
        
        XCTAssert(FileManager.default.fileExists(atPath: downloadFile.path))
        XCTAssert(FileManager.default.fileExists(atPath: tutorialFile.path))
        XCTAssert(FileManager.default.fileExists(atPath: tutorialOverviewFile.path))
        
        // Documentation bundle that contains a download and a tutorial that references it
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: downloadFile),
            CopyOfFile(original: tutorialFile),
            CopyOfFile(original: tutorialOverviewFile),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "downloads", content: [
               CopyOfFile(original: downloadFile),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    // Ensures we always create the required asset folders even if no assets are explicitly
    // provided
    func testCreationOfAssetFolders() throws {
        // Empty documentation bundle
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "downloads", content: []),
            Folder(name: "images", content: []),
            Folder(name: "videos", content: []),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    func testConvertsWithoutErrorsWhenBundleIsNotAtRoot() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let input = Folder(name: "nested", content: [Folder(name: "folders", content: [bundle, Folder.emptyHTMLTemplateDirectory])])

        let testDataProvider = try TestFileSystem(folders: [input, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: input.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)
        XCTAssertEqual(result.problems.count, 0)
    }
    
    func testConvertWithoutBundle() throws {
        let myKitSymbolGraph = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json")
        
        XCTAssert(FileManager.default.fileExists(atPath: myKitSymbolGraph.path))
        let symbolGraphFiles = Folder(name: "Not-a-doc-bundle", content: [
            CopyOfFile(original: myKitSymbolGraph, newName: "MyKit.symbols.json")
        ])
        
        let outputLocation = Folder(name: "output", content: [])
        
        let testDataProvider = try TestFileSystem(folders: [Folder.emptyHTMLTemplateDirectory, symbolGraphFiles, outputLocation])
        
        var infoPlistFallbacks = [String: Any]()
        infoPlistFallbacks["CFBundleDisplayName"] = "MyKit" // same as the symbol graph
        infoPlistFallbacks["CFBundleIdentifier"] = "com.example.test"
        infoPlistFallbacks["CFBundleVersion"] = "1.2.3"
        infoPlistFallbacks["CDDefaultCodeListingLanguage"] = "swift"
        
        var action = try ConvertAction(
            documentationBundleURL: nil,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: outputLocation.absoluteURL,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            fileManager: testDataProvider,
            bundleDiscoveryOptions: BundleDiscoveryOptions(
                infoPlistFallbacks: infoPlistFallbacks,
                additionalSymbolGraphFiles: [URL(fileURLWithPath: "/Not-a-doc-bundle/MyKit.symbols.json")]
            )
        )
        
        let result = try action.perform(logHandle: .standardOutput)
        XCTAssertEqual(result.problems.count, 0)
        XCTAssertEqual(result.outputs, [outputLocation.absoluteURL])
        
        let outputData = testDataProvider.files.filter { $0.key.hasPrefix("/output/data/documentation/") }
        
        XCTAssertEqual(outputData.keys.sorted(), [
            "/output/data/documentation/mykit",
            "/output/data/documentation/mykit.json",
            "/output/data/documentation/mykit/myclass",
            "/output/data/documentation/mykit/myclass.json",
            "/output/data/documentation/mykit/myclass/init()-33vaw.json",
            "/output/data/documentation/mykit/myclass/init()-3743d.json",
            "/output/data/documentation/mykit/myclass/myfunction().json",
            "/output/data/documentation/mykit/myprotocol.json",
            "/output/data/documentation/mykit/globalfunction(_:considering:).json",
        ].sorted())
        
        let myKitNodeData = try XCTUnwrap(outputData["/output/data/documentation/mykit.json"])
        let myKitNode = try JSONDecoder().decode(RenderNode.self, from: myKitNodeData)
        
        // Verify that framework page doesn't get automatic abstract
        XCTAssertEqual(myKitNode.abstract, [.text("")])
        XCTAssertTrue(myKitNode.primaryContentSections.isEmpty)
        XCTAssertEqual(myKitNode.topicSections.count, 3) // Automatic curation of the symbols in the symbol graph file
        
        // Verify that non-framework symbols do get automatic abstract.
        let myProtocolNodeData = try XCTUnwrap(outputData["/output/data/documentation/mykit/myprotocol.json"])
        let myProtocolNode = try JSONDecoder().decode(RenderNode.self, from: myProtocolNodeData)
        XCTAssertEqual(myProtocolNode.abstract, [.text("No overview available.")])
    }
    
    func testConvertWithoutBundleErrorMessage() throws {
        let myKitSymbolGraph = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json")
        
        XCTAssert(FileManager.default.fileExists(atPath: myKitSymbolGraph.path))
        let symbolGraphFiles = Folder(name: "Not-a-doc-bundle", content: [
            CopyOfFile(original: myKitSymbolGraph, newName: "MyKit.symbols.json"),
        ])
        
        let outputLocation = Folder(name: "output", content: [])
        
        let testDataProvider = try TestFileSystem(folders: [Folder.emptyHTMLTemplateDirectory, symbolGraphFiles, outputLocation])
        
        var infoPlistFallbacks = [String: Any]()
        infoPlistFallbacks["CFBundleIdentifier"] = "com.example.test"
        
        var action = try ConvertAction(
            documentationBundleURL: nil,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: outputLocation.absoluteURL,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            fileManager: testDataProvider,
            bundleDiscoveryOptions: BundleDiscoveryOptions(
                infoPlistFallbacks: infoPlistFallbacks,
                additionalSymbolGraphFiles: [URL(fileURLWithPath: "/Not-a-doc-bundle/MyKit.symbols.json")]
            )
        )
        let logStorage = LogHandle.LogStorage()
        XCTAssertThrowsError(try action.perform(logHandle: .memory(logStorage))) { error in
            XCTAssertEqual(error.localizedDescription, """
            The information provided as command line arguments is not enough to generate a documentation bundle:
            
            Missing value for 'CFBundleDisplayName'.
            Use the '--fallback-display-name' argument or add 'CFBundleDisplayName' to the bundle Info.plist.
            
            """)
        }
    }

    func testMoveOutputCreatesTargetFolderParent() throws {
        // Source folder to test moving
        let source = Folder(name: "source", content: [
            TextFile(name: "index.html", utf8Content: ""),
        ])

        // The target location to test moving to
        let target = Folder(name: "target", content: [
            Folder(name: "output", content: []),
        ])
        
        // We add only the source to the file system
        let testDataProvider = try TestFileSystem(folders: [source, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        let action = try ConvertAction(
            documentationBundleURL: source.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        
        let targetURL = target.absoluteURL.appendingPathComponent("output")
        
        XCTAssertNoThrow(try action.moveOutput(from: source.absoluteURL, to: targetURL))
        XCTAssertTrue(testDataProvider.fileExists(atPath: targetURL.path, isDirectory: nil))
        XCTAssertFalse(testDataProvider.fileExists(atPath: source.absoluteURL.path, isDirectory: nil))
    }
    
    func testMoveOutputDoesNotCreateIntermediateTargetFolderParents() throws {
        // Source folder to test moving
        let source = Folder(name: "source", content: [
            TextFile(name: "index.html", utf8Content: ""),
        ])

        // The target location to test moving to
        let target = Folder(name: "intermediate", content: [
            Folder(name: "target", content: [
                Folder(name: "output", content: []),
            ])
        ])
        
        // We add only the source to the file system
        let testDataProvider = try TestFileSystem(folders: [source, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        let action = try ConvertAction(
            documentationBundleURL: source.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        
        let targetURL = target.absoluteURL.appendingPathComponent("target").appendingPathComponent("output")
        
        XCTAssertThrowsError(try action.moveOutput(from: source.absoluteURL, to: targetURL))
    }

    func testConvertDoesNotLowercasesResourceFileNames() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: imageFile, newName: "TEST.png"),
            CopyOfFile(original: imageFile, newName: "VIDEO.mov"),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "images", content: [
               CopyOfFile(original: imageFile, newName: "TEST.png"),
            ]),
            Folder(name: "videos", content: [
               CopyOfFile(original: imageFile, newName: "VIDEO.mov"),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    // Ensures that render JSON produced by the convert action
    // does not include file location information for symbols.
    func testConvertDoesNotIncludeFilePathsInRenderNodes() throws {
        // Documentation bundle that contains a symbol graph.
        // The symbol graph contains symbols that include location information.
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: symbolGraphFile),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .none)
        
        // Construct the URLs for the produced render json:
        
        let documentationDataDirectoryURL = result.outputs[0]
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent("documentation", isDirectory: true)
        
        let fillIntroducedDirectoryURL = documentationDataDirectoryURL
            .appendingPathComponent("fillintroduced", isDirectory: true)
            
        let renderNodeURLs = [
            documentationDataDirectoryURL
                .appendingPathComponent("fillintroduced.json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("macosonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("macosonlyintroduced().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosmacosonly().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosonlyintroduced().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("maccatalystonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("maccatalystonlyintroduced().json", isDirectory: false),
        ]
        
        let decoder = JSONDecoder()
        
        // Process all of the render JSON:
        try renderNodeURLs.forEach { renderNodeURL in
            // Get the data for the render json
            let renderNodeJSON = try testDataProvider.contentsOfURL(renderNodeURL)
            
            // Decode the render node
            let renderNode = try decoder.decode(RenderNode.self, from: renderNodeJSON)
            
            // Confirm that the render node didn't contain the location information
            // from the symbol graph
            XCTAssertNil(renderNode.metadata.sourceFileURI)
        }
    }
    
    // Ensures that render JSON produced by the convert action does not include symbol access level information.
    func testConvertDoesNotIncludeSymbolAccessLevelsInRenderNodes() throws {
        // Documentation bundle that contains a symbol graph.
        // The symbol graph contains symbols that include access level information.
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: symbolGraphFile),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .none)
        
        // Construct the URLs for the produced render json:
        
        let documentationDataDirectoryURL = result.outputs[0]
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent("documentation", isDirectory: true)
        
        let fillIntroducedDirectoryURL = documentationDataDirectoryURL
            .appendingPathComponent("fillintroduced", isDirectory: true)
            
        let renderNodeURLs = [
            documentationDataDirectoryURL
                .appendingPathComponent("fillintroduced.json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("macosonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("macosonlyintroduced().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosmacosonly().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosonlyintroduced().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("maccatalystonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("maccatalystonlyintroduced().json", isDirectory: false),
        ]
        
        let decoder = JSONDecoder()
        
        // Process all of the render JSON:
        try renderNodeURLs.forEach { renderNodeURL in
            // Get the data for the render json
            let renderNodeJSON = try testDataProvider.contentsOfURL(renderNodeURL)
            
            // Decode the render node
            let renderNode = try decoder.decode(RenderNode.self, from: renderNodeJSON)
            
            // Confirm that the render node didn't contain the access level of symbols.
            XCTAssertNil(renderNode.metadata.symbolAccessLevel)
        }
    }

    func testOutputFolderContainsDiagnosticJSONWhenThereAreWarnings() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: imageFile, newName: "referenced-tutorials-image.png"),
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Tutorials(name: "Technology X") {
                   @Intro(title: "Technology X") {
                      You'll learn all about Technology X.
                   }
                   
                   @Volume(name: "Volume 1") {
                      This volume contains Chapter 1.

                      @Image(source: referenced-tutorials-image, alt: "Some alt text")

                      @Chapter(name: "Chapter 1") {
                         In this chapter, you'll learn about Tutorial 1.

                         @Image(source: referenced-tutorials-image, alt: "Some alt text")
                      }
                   }
                }
                """
            ),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)

        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "images", content: [
               CopyOfFile(original: imageFile, newName: "referenced-tutorials-image.png"),
            ]),
            Folder(name: "videos", content: [
            ]),
            JSONFile(name: "diagnostics.json", content: [
                Digest.Diagnostic(
                    start: .init(line: 11, column: 7),
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .warning,
                    summary: "The 'Chapter' directive requires at least one 'TutorialReference' child directive",
                    explanation: nil,
                    notes: []
                ),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    /// Ensures that we always generate diagnosticJSON when there are errors. (rdar://72345373)
    func testOutputFolderContainsDiagnosticJSONWhenThereAreErrorsAndNoTemplate() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Article(time: 10) {
                   @Intro(title: "Technology X") {
                      You'll learn all about Technology X.
                   }
                
                   @Intro(title: "Technology X") {
                      You'll learn all about Technology X.
                   }
                }
                """
            ),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            diagnosticLevel: "hint") // report all errors during the test
        let result = try action.perform(logHandle: .standardOutput)

        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            JSONFile(name: "diagnostics.json", content: [
                Digest.Diagnostic(
                    start: .init(line: 6, column: 4),
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .warning,
                    summary: "Duplicate 'Intro' child directive",
                    explanation: "The 'Article' directive must have exactly one 'Intro' child directive",
                    notes: []
                ),
                Digest.Diagnostic(
                    start: nil,
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .warning,
                    summary: "The article 'TechnologyX' must be referenced from a Tutorial Table of Contents",
                    explanation: nil,
                    notes: []
                ),
                Digest.Diagnostic(
                    start: nil,
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .information,
                    summary: "You haven't curated 'doc://com.test.example/tutorials/TestBundle/TechnologyX'",
                    explanation: nil,
                    notes: []
                ),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    func testWarningForUncuratedTutorial() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Tutorial(time: 10) {
                  @Intro(title: "TechologyX") {}

                  @Section(title: "Section") {
                    @Steps {}
                  }

                  @Assessments {
                    @MultipleChoice {
                      text
                      @Choice(isCorrect: true) {
                        text
                        @Justification(reaction: "reaction text") {}
                      }

                      @Choice(isCorrect: false) {
                        text
                        @Justification(reaction: "reaction text") {}
                      }
                    }
                  }
                }
                """
            ),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            diagnosticLevel: "hint") // report all errors during the test
        let result = try action.perform(logHandle: .standardOutput)

        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            JSONFile(name: "diagnostics.json", content: [
                Digest.Diagnostic(
                    start: nil,
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .warning,
                    summary: "The tutorial 'TechnologyX' must be referenced from a Tutorial Table of Contents",
                    explanation: nil,
                    notes: []
                ),
                Digest.Diagnostic(
                    start: nil,
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .information,
                    summary: "You haven't curated 'doc://com.test.example/tutorials/TestBundle/TechnologyX'",
                    explanation: nil,
                    notes: []
                ),
            ])
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    /// Ensures we never delete an existing build folder if conversion fails (rdar://72339050)
    func testOutputFolderIsNotRemovedWhenThereAreErrors() throws {
        let tutorialsFile = TextFile(name: "TechnologyX.tutorial", utf8Content: """
            @Tutorials(name: "Technology Z") {
               @Intro(title: "Technology Z") {
                  Intro text.
               }
               
               @Volume(name: "Volume A") {
                  This is a volume.

                  @Chapter(name: "Getting Started") {
                     In this chapter, you'll learn about Tutorial 1. Feel free to add more `TutorialReference`s below.

                     @TutorialReference(tutorial: "doc:Tutorial" )
                  }
               }
            }
            """
        )
        
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Article(time: 20) {
               @Intro(title: "Basic Augmented Reality App") {
                  This is curated under a Swift page and and ObjC page.
               }
            }
            """
        )
        
        let bundleInfoPlist = InfoPlist(displayName: "TestBundle", identifier: "com.test.example")
        
        let goodBundle = Folder(name: "unit-test.docc", content: [
            tutorialsFile,
            tutorialFile,
            bundleInfoPlist,
        ])
        
        let badBundle = Folder(name: "unit-test.docc", content: [
            incompleteSymbolGraphFile,
            bundleInfoPlist,
        ])
        
        let testDataProvider = try TestFileSystem(folders: [goodBundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        do {
            var action = try ConvertAction(
                documentationBundleURL: goodBundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider)
            let result = try action.perform(logHandle: .standardOutput)
            
            XCTAssertFalse(
                result.didEncounterError,
                "Unexpected error occurred during conversion of test bundle."
            )
            
            // Verify that the build output folder was successfully created
            let expectedOutput = Folder(name: ".docc-build", content: [
                Folder(name: "data", content: [
                    Folder(name: "tutorials", content: []),
                ]),
            ])
            expectedOutput.assertExist(at: targetDirectory, fileManager: testDataProvider)
        }
        
        try testDataProvider.updateDocumentationBundles(withFolders: [badBundle])
        
        do {
            var action = try ConvertAction(
                documentationBundleURL: badBundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider)
            let result = try action.perform(logHandle: .standardOutput)

            XCTAssert(
                result.didEncounterError,
                "We expect errors to occur during during conversion of the bad test bundle."
            )

            // Verify that the build output folder from the former successful conversion
            // still exists after this failure.
            let expectedOutput = Folder(name: ".docc-build", content: [
                Folder(name: "data", content: [
                ]),
            ])
            expectedOutput.assertExist(at: targetDirectory, fileManager: testDataProvider)
        }
    }
    
    func testOutputFolderContainsDiagnosticJSONWhenThereAreErrors() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            incompleteSymbolGraphFile,
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)

        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            JSONFile(name: "diagnostics.json", content: [
                Digest.Diagnostic(
                    start: nil,
                    source: nil,
                    severity: .error,
                    summary: "Symbol with identifier 's:5MyKit0A5ProtocolP' couldn't be found",
                    explanation: nil,
                    notes: []
                ),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }

    /// Verifies that digest is correctly emitted for API documentation topics
    /// like module pages, symbols, and articles.
    func testMetadataIsWrittenToOutputFolderAPIDocumentation() throws {
        // Example documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            // An asset
            CopyOfFile(original: imageFile, newName: "image.png"),
            
            // An Article
            TextFile(name: "Article.md", utf8Content: """
                # This is an article
                Article abstract.
                
                Discussion content
                
                ![my image](image.png)
                
                ## Article Section
                
                This is another section of the __article__.
                """
            ),

            // A module page
            TextFile(name: "TestBed.md", utf8Content: """
                # ``TestBed``
                TestBed abstract.
                
                TestBed discussion __content__.
                ## Topics
                ### Basics
                - <doc:Article>
                """
            ),

            // A symbol doc extensions
            TextFile(name: "A.md", utf8Content: """
                # ``TestBed/A``
                An abstract.
                
                `A` discussion __content__.
                """
            ),

            // A symbol graph
            CopyOfFile(original: Bundle.module.url(forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!),
            
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        func contentsOfJSONFile<Result: Decodable>(url: URL) -> Result? {
            guard let data = testDataProvider.contents(atPath: url.path) else {
                return nil
            }
            return try? JSONDecoder().decode(Result.self, from: data)
        }

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)

        // Because the page order isn't deterministic, we create the indexing records and linkable entities in the same order as the pages.
        let indexingRecords: [IndexingRecord] = action.context.knownPages.compactMap { reference in
            switch reference.path {
            case "/documentation/TestBed":
                return IndexingRecord(
                    kind: .symbol,
                    location: .topLevelPage(reference),
                    title: "TestBed",
                    summary: "TestBed abstract.",
                    headings: ["Overview"],
                    rawIndexableTextContent: "TestBed abstract. Overview TestBed discussion content."
                )
            case "/documentation/TestBed/A":
                return IndexingRecord(
                    kind: .symbol,
                    location: .topLevelPage(reference),
                    title: "A",
                    summary: "An abstract.",
                    headings: ["Overview"],
                    rawIndexableTextContent: "An abstract. Overview A discussion content."
                )
            case "/documentation/TestBundle/Article":
                return IndexingRecord(
                    kind: .article,
                    location: .topLevelPage(reference),
                    title: "This is an article",
                    summary: "Article abstract.",
                    headings: ["Overview", "Article Section"],
                    rawIndexableTextContent: "Article abstract. Overview Discussion content  Article Section This is another section of the article."
                )
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return nil
            }
        }
        let linkableEntities = action.context.knownPages.flatMap { (reference: ResolvedTopicReference) -> [LinkDestinationSummary] in
            switch reference.path {
            case "/documentation/TestBed":
                return [
                    LinkDestinationSummary(
                        kind: .module,
                        path: "/documentation/testbed",
                        referenceURL: reference.url,
                        title: "TestBed",
                        language: .swift,
                        abstract: "TestBed abstract.",
                        taskGroups: [
                            .init(title: "Basics", identifiers: ["doc://com.test.example/documentation/TestBundle/Article"]),
                            .init(title: "Structures", identifiers: ["doc://com.test.example/documentation/TestBed/A"]),
                        ],
                        usr: "TestBed",
                        availableLanguages: [.swift],
                        platforms: nil,
                        redirects: nil
                    ),
                ]
            case "/documentation/TestBed/A":
                return [
                    LinkDestinationSummary(
                        kind: .structure,
                        path: "/documentation/testbed/a",
                        referenceURL: reference.url,
                        title: "A",
                        language: .swift,
                        abstract: "An abstract.",
                        taskGroups: [],
                        usr: "s:7TestBed1AV",
                        availableLanguages: [.swift],
                        platforms: nil,
                        redirects: nil
                    ),
                ]
            case "/documentation/TestBundle/Article":
                return [
                    LinkDestinationSummary(
                        kind: .article,
                        path: "/documentation/testbundle/article",
                        referenceURL: reference.url,
                        title: "This is an article",
                        language: .swift,
                        abstract: "Article abstract.",
                        taskGroups: [],
                        availableLanguages: [.swift],
                        platforms: nil,
                        redirects: nil
                    ),
                ]
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return []
            }
        }
        let images: [ImageReference] = action.context.knownPages.flatMap {
            reference -> [ImageReference] in
            switch reference.path {
            case "/documentation/TestBundle/Article":
                return [ImageReference(
                    name: "image.png",
                    altText: "my image",
                    userInterfaceStyle: .light,
                    displayScale: .standard
                )]
            default:
                return []
            }
        }

        // Verify diagnostics
        guard let resultDiagnostics: [Digest.Diagnostic] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("diagnostics.json")) else {
            XCTFail("Can't find diagnostics.json in output")
            return
        }
        XCTAssertTrue(resultDiagnostics.isEmpty)
        
        // Verify indexing records
        let indexingRecordSort: (IndexingRecord, IndexingRecord) -> Bool = { return $0.title < $1.title }
        guard let resultIndexingRecords: [IndexingRecord] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("indexing-records.json")) else {
            XCTFail("Can't find indexing-records.json in output")
            return
        }
        XCTAssertEqual(resultIndexingRecords.sorted(by: indexingRecordSort), indexingRecords.sorted(by: indexingRecordSort))

        // Verify linkable entities
        let linkableEntitiesSort: (LinkDestinationSummary, LinkDestinationSummary) -> Bool = { return $0.referenceURL.absoluteString < $1.referenceURL.absoluteString }
        guard let resultLikableEntities: [LinkDestinationSummary] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("linkable-entities.json")) else {
            XCTFail("Can't find linkable-entities.json in output")
            return
        }
        XCTAssertEqual(resultLikableEntities.sorted(by: linkableEntitiesSort), linkableEntities.sorted(by: linkableEntitiesSort))
        
        // Verify images
        guard let resultAssets: Digest.Assets = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("assets.json")) else {
            XCTFail("Can't find assets.json in output")
            return
        }
        XCTAssertEqual(resultAssets.images.map({ $0.identifier.identifier }).sorted(), images.map({ $0.identifier.identifier }).sorted())
    }

    func testMetadataIsWrittenToOutputFolder() throws {
        // Example documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: imageFile, newName: "referenced-article-image.png"),
            CopyOfFile(original: imageFile, newName: "referenced-tutorials-image.png"),
            CopyOfFile(original: imageFile, newName: "UNreferenced-image.png"),
            
            TextFile(name: "Article.tutorial", utf8Content: """
                @Article(time: 20) {
                   @Intro(title: "Making an Augmented Reality App") {
                      This is an abstract for the intro.
                   }
                   
                   ## Section Name
                   
                   ![full width image](referenced-article-image.png)
                }
                """
            ),
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Tutorials(name: TechnologyX) {
                   @Intro(title: "Technology X") {
                      Learn about some stuff in Technology X.
                   }
                   
                   @Volume(name: "Volume 1") {
                      This volume contains Chapter 1.

                      @Image(source: referenced-tutorials-image.png, alt: "Some alt text")

                      @Chapter(name: "Chapter 1") {
                         In this chapter, you'll learn about Tutorial 1.

                         @Image(source: referenced-tutorials-image.png, alt: "Some alt text")
                         @TutorialReference(tutorial: "doc:Article")
                      }
                   }

                }
                """
            ),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        func contentsOfJSONFile<Result: Decodable>(url: URL) -> Result? {
            guard let data = testDataProvider.contents(atPath: url.path) else {
                return nil
            }
            return try? JSONDecoder().decode(Result.self, from: data)
        }

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        let result = try action.perform(logHandle: .standardOutput)
        
        // Because the page order isn't deterministic, we create the indexing records and linkable entities in the same order as the pages.
        let indexingRecords: [IndexingRecord] = action.context.knownPages.compactMap { reference in
            switch reference.path {
            case "/tutorials/TestBundle/Article":
                return IndexingRecord(
                    kind: .article,
                    location: .topLevelPage(reference),
                    title: "Making an Augmented Reality App",
                    summary: "This is an abstract for the intro.",
                    headings: ["Section Name"],
                    rawIndexableTextContent: "This is an abstract for the intro. Section Name "
                )
            case "/tutorials/TechnologyX":
                return IndexingRecord(
                    kind: .overview,
                    location: .topLevelPage(reference),
                    title: "Technology X",
                    summary: "Learn about some stuff in Technology X.",
                    headings: ["Volume 1"],
                    rawIndexableTextContent: "Learn about some stuff in Technology X. This volume contains Chapter 1."
                )
            case "/": return nil
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return nil
            }
        }
        let linkableEntities = action.context.knownPages.flatMap { (reference: ResolvedTopicReference) -> [LinkDestinationSummary] in
            switch reference.path {
            case "/tutorials/TestBundle/Article":
                return [
                    LinkDestinationSummary(
                        kind: .tutorialArticle,
                        path: "/tutorials/testbundle/article",
                        referenceURL: reference.url,
                        title: "Making an Augmented Reality App",
                        language: .swift,
                        abstract: "This is an abstract for the intro.",
                        taskGroups: [.init(title: nil, identifiers: [reference.withFragment("Section-Name").absoluteString])],
                        availableLanguages: [.swift],
                        platforms: nil,
                        redirects: nil
                    ),
                    LinkDestinationSummary(
                        kind: .onPageLandmark,
                        path: "/tutorials/testbundle/article#Section-Name",
                        referenceURL: reference.withFragment("Section-Name").url,
                        title: "Section Name",
                        language: .swift,
                        abstract: nil,
                        taskGroups: [],
                        availableLanguages: [.swift],
                        platforms: nil,
                        redirects: nil
                    ),
                ]
            case "/tutorials/TechnologyX":
                return [
                    LinkDestinationSummary(
                        kind: .technology,
                        path: "/tutorials/technologyx",
                        referenceURL: reference.url,
                        title: "Technology X",
                        language: .swift,
                        abstract: "Learn about some stuff in Technology X.",
                        taskGroups: [.init(title: nil, identifiers: [reference.appendingPath("Volume-1").absoluteString])],
                        availableLanguages: [.swift],
                        platforms: nil,
                        redirects: nil
                    ),
                ]
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return []
            }
        }
        let images: [ImageReference] = action.context.knownPages.flatMap {
            reference -> [ImageReference] in
            switch reference.path {
            case "/tutorials/TestBundle/Article":
                return [ImageReference(
                    name: "referenced-article-image.png",
                    altText: "full width image",
                    userInterfaceStyle: .light,
                    displayScale: .standard
                )]
            case "/tutorials/TechnologyX":
                return [ImageReference(
                    name: "referenced-tutorials-image.png",
                    altText: "Some alt text",
                    userInterfaceStyle: .light,
                    displayScale: .standard
                )]
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return []
            }
        }
        
        // Verify diagnostics
        guard let resultDiagnostics: [Digest.Diagnostic] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("diagnostics.json")) else {
            XCTFail("Can't find diagnostics.json in output")
            return
        }
        XCTAssertTrue(resultDiagnostics.isEmpty)
        
        // Verify indexing records
        let indexingRecordSort: (IndexingRecord, IndexingRecord) -> Bool = { return $0.title < $1.title }
        guard let resultIndexingRecords: [IndexingRecord] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("indexing-records.json")) else {
            XCTFail("Can't find indexing-records.json in output")
            return
        }
        XCTAssertEqual(resultIndexingRecords.sorted(by: indexingRecordSort), indexingRecords.sorted(by: indexingRecordSort))
        
        // Verify linkable entities
        let linkableEntitiesSort: (LinkDestinationSummary, LinkDestinationSummary) -> Bool = { return $0.referenceURL.absoluteString < $1.referenceURL.absoluteString }
        guard let resultLikableEntities: [LinkDestinationSummary] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("linkable-entities.json")) else {
            XCTFail("Can't find linkable-entities.json in output")
            return
        }
        XCTAssertEqual(resultLikableEntities.sorted(by: linkableEntitiesSort), linkableEntities.sorted(by: linkableEntitiesSort))
        
        // Verify images
        guard let resultAssets: Digest.Assets = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("assets.json")) else {
            XCTFail("Can't find assets.json in output")
            return
        }
        XCTAssertEqual(resultAssets.images.map({ $0.identifier.identifier }).sorted(), images.map({ $0.identifier.identifier }).sorted())
    }
    
    func testMetadataIsOnlyWrittenToOutputFolderWhenEmitDigestFlagIsSet() throws {
        
        // An empty documentation bundle
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        // Check that they're all written when `--emit-digest` is set
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: true, // emit digest files
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider)
            let result = try action.perform(logHandle: .standardOutput)
            
            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("assets.json").path))
            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("diagnostics.json").path))
            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("indexing-records.json").path))
            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("linkable-entities.json").path))
        }
        
        // Check that they're not written when `--emit-digest` is not set
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false, // don't emit digest files
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider)
            let result = try action.perform(logHandle: .standardOutput)
            
            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("assets.json").path))
            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("diagnostics.json").path))
            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("indexing-records.json").path))
            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("linkable-entities.json").path))
        }
    }

    func testMetadataIsOnlyWrittenToOutputFolderWhenDocumentationCoverage() throws {

        // An empty documentation bundle
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        // Check that they're nothing is written for `.noCoverage`
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                documentationCoverageOptions: .noCoverage)
            let result = try action.perform(logHandle: .standardOutput)

            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("documentation-coverage.json").path))
        }

        // Check that JSON is written for `.brief`
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                documentationCoverageOptions: DocumentationCoverageOptions(level: .brief))
            let result = try action.perform(logHandle: .standardOutput)

            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("documentation-coverage.json").path))
        }

        // Check that JSON is written for `.detailed`
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                documentationCoverageOptions: DocumentationCoverageOptions(level: .detailed))
            let result = try action.perform(logHandle: .standardOutput)

            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("documentation-coverage.json").path))
        }
    }
    
    /// Test context gets the current platforms provided by command line.
    func testRelaysCurrentPlatformsToContext() throws {
        // Empty documentation bundle that's nested inside some other directories.
        let bundle = Folder(name: "nested", content: [
            Folder(name: "folders", content: [
                Folder(name: "unit-test.docc", content: [
                    InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
                ]),
            ])
        ])
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        let action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: [
                "platform1": PlatformVersion(.init(10, 11, 12), beta: false),
                "platform2": PlatformVersion(.init(11, 12, 13), beta: false),
            ],
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        
        XCTAssertEqual(action.context.externalMetadata.currentPlatforms, [
            "platform1" : PlatformVersion(.init(10, 11, 12), beta: false),
            "platform2" : PlatformVersion(.init(11, 12, 13), beta: false),
        ])
    }

    func testIgnoresAnalyzerHintsByDefault() throws {
        func runCompiler(analyze: Bool) throws -> [Problem] {
            // This bundle has both non-analyze and analyze style warnings.
            let testBundleURL = Bundle.module.url(
                forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            let bundle = try Folder.createFromDisk(url: testBundleURL)

            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            let engine = DiagnosticEngine()
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: analyze, // Turn on/off the analyzer.
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                diagnosticEngine: engine)
            let result = try action.perform(logHandle: .standardOutput)
            XCTAssertFalse(result.didEncounterError)
            return engine.problems
        }

        let analyzeDiagnostics = try runCompiler(analyze: true)
        let noAnalyzeDiagnostics = try runCompiler(analyze: false)
        
        XCTAssertTrue(analyzeDiagnostics.contains { $0.diagnostic.severity == .information })
        XCTAssertFalse(noAnalyzeDiagnostics.contains { $0.diagnostic.severity == .information })

        XCTAssertTrue(
            analyzeDiagnostics.count > noAnalyzeDiagnostics.count,
            """
                The number of diagnostics with '--analyze' should be more than without '--analyze' \
                (\(analyzeDiagnostics.count) vs \(noAnalyzeDiagnostics.count))
                """
        )
    }
    
    /// Verify that the conversion of the same input given high concurrency and no concurrency,
    /// and also with and without generating digest produces the same results
    func testConvertTestBundleWithHighConcurrency() throws {
        let testBundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let bundle = try Folder.createFromDisk(url: testBundleURL)

        struct TestReferenceResolver: ExternalReferenceResolver {
            let customResolvedURL = URL(string: "https://resolved.com/resolved/path?query=item")!

            func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult {
                return .success(ResolvedTopicReference(bundleIdentifier: "com.example.test", path: reference.url!.path, sourceLanguage: .swift))
            }

            func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode {
                return DocumentationNode(
                    reference: reference,
                    kind: .article,
                    sourceLanguage: .swift,
                    availableSourceLanguages: nil,
                    name: .conceptual(title: reference.url.pathComponents.last!.capitalized),
                    markup: Paragraph(),
                    semantic: nil,
                    platformNames: nil
                )
            }

            func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL {
                return URL(string: "https://resolved.com\(reference.path)")!
            }
        }
        
        func convertTestBundle(batchSize: Int, emitDigest: Bool, targetURL: URL, testDataProvider: DocumentationWorkspaceDataProvider & FileManagerProtocol) throws -> ActionResult {
            // Run the create ConvertAction
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetURL,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: emitDigest,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider)
            
            action.converter.batchNodeCount = batchSize
            
            action.context.externalReferenceResolvers["com.example.test"] = TestReferenceResolver()
            
            return try action.perform(logHandle: .standardOutput)
        }

        for withDigest in [false, true] {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])

            // Set a batch size to a high number to have no concurrency
            let serialOutputURL = URL(string: "/serialOutput")!
            let serialResult = try convertTestBundle(batchSize: 10_000, emitDigest: withDigest, targetURL: serialOutputURL, testDataProvider: testDataProvider)

            // Set a batch size to 1 to have maximum concurrency (this is bad for performance maximizes our chances of encountering an issue).
            let parallelOutputURL = URL(string: "/parallelOutput")!
            let parallelResult = try convertTestBundle(batchSize: 1, emitDigest: withDigest, targetURL: parallelOutputURL, testDataProvider: testDataProvider)
            
            // Compare the results
            XCTAssertEqual(
                uniformlyPrintDiagnosticMessages(serialResult.problems),
                uniformlyPrintDiagnosticMessages(parallelResult.problems)
            )
            
            XCTAssertEqual(parallelResult.outputs.count, 1)
            XCTAssertEqual(serialResult.outputs.count, 1)
            
            guard let serialOutput = serialResult.outputs.first, let parallelOutput = parallelResult.outputs.first else {
                XCTFail("Missing output to compare")
                return
            }
            
            let serialContent = testDataProvider.files.keys.filter({ $0.hasPrefix(serialOutput.path) })
            let parallelContent = testDataProvider.files.keys.filter({ $0.hasPrefix(parallelOutput.path) })

            XCTAssertFalse(serialContent.isEmpty)
            XCTAssertEqual(serialContent.count, parallelContent.count)
            
            let relativePathsSerialContent = serialContent.map({ $0.replacingOccurrences(of: serialOutput.path, with: "") })
            let relativePathsParallelContent = parallelContent.map({ $0.replacingOccurrences(of: parallelOutput.path, with: "") })

            XCTAssertEqual(relativePathsSerialContent.sorted(), relativePathsParallelContent.sorted())
        }
    }
    
    func testConvertActionProducesDeterministicOutput() throws {
        // Pretty printing the output JSON also enables sorting keys during encoding
        // which is required for testing if the conversion output is deterministic.
        let priorPrettyPrintValue = shouldPrettyPrintOutputJSON
        shouldPrettyPrintOutputJSON = true
        defer {
            // Because this value is being modified in-process (not in the environment)
            // it will not affect the outcome of other tests, even when running tests in parallel.
            // Even when tests are run in parallel,
            // there is only one test being executed per process at a time.
            shouldPrettyPrintOutputJSON = priorPrettyPrintValue
        }
        
        let testBundleURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "TestBundle",
                withExtension: "docc",
                subdirectory: "Test Bundles"
            )
        )
        let bundle = try Folder.createFromDisk(url: testBundleURL)
        
        func performConvertAction(outputURL: URL, testFileSystem: TestFileSystem) throws {
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: outputURL,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testFileSystem,
                fileManager: testFileSystem
            )
            
            _ = try action.perform(logHandle: .none)
        }
        
        // We'll perform 3 sets of conversions to confirm the output is deterministic
        for _ in 1...3 {
            let testFileSystem = try TestFileSystem(
                folders: [bundle, Folder.emptyHTMLTemplateDirectory]
            )
            
            // Convert the same bundle three times and place the output in
            // separate directories.
            
            try performConvertAction(
                outputURL: URL(fileURLWithPath: "/1", isDirectory: true),
                testFileSystem: testFileSystem
            )
            try performConvertAction(
                outputURL: URL(fileURLWithPath: "/2", isDirectory: true),
                testFileSystem: testFileSystem
            )
            
            // Extract and sort the RenderJSON output of each conversion
            
            let firstConversionFiles = testFileSystem.files.lazy.filter { key, _ in
                key.hasPrefix("/1/data/")
            }.map { (key, value) in
                return (String(key.dropFirst("/1".count)), value)
            }.sorted(by: \.0)
            
            let secondConversionFiles = testFileSystem.files.lazy.filter { key, _ in
                key.hasPrefix("/2/data/")
            }.map { (key, value) in
                return (String(key.dropFirst("/2".count)), value)
            }.sorted(by: \.0)
            
            // Zip the two sets of sorted files and loop through them, ensuring that
            // each conversion produced the same RenderJSON output.
            
            XCTAssertEqual(
                firstConversionFiles.map(\.0),
                secondConversionFiles.map(\.0),
                "The produced file paths are nondeterministic."
            )
            
            for (first, second) in zip(firstConversionFiles, secondConversionFiles) {
                let firstString = String(data: first.1, encoding: .utf8)
                let secondString = String(data: second.1, encoding: .utf8)
                
                XCTAssertEqual(firstString, secondString, "The contents of '\(first.0)' is nondeterministic.")
            }
        }
    }
    
    func testConvertActionNavigatorIndexGeneration() throws {
        // The navigator index needs to test with the real file manager
        let bundleURL = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let targetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
        defer { try? fileManager.removeItem(at: targetURL) }
        
        let templateURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try Folder.emptyHTMLTemplateDirectory.write(to: templateURL)
        defer { try? fileManager.removeItem(at: templateURL) }
        
        // Convert the documentation and create an index
        
        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            buildIndex: true // Create an index
        )
        _ = try action.perform(logHandle: .standardOutput)
        
        let indexURL = targetURL.appendingPathComponent("index")
        
        let indexFromConvertAction = try NavigatorIndex(url: indexURL)
        XCTAssertEqual(indexFromConvertAction.count, 37)
        
        try fileManager.removeItem(at: indexURL)
        
        // Run just the index command over the built documentation
        
        var indexAction = try IndexAction(
            documentationBundleURL: targetURL,
            outputURL: indexURL,
            bundleIdentifier: indexFromConvertAction.bundleIdentifier
        )
        _ = try indexAction.perform(logHandle: .standardOutput)
        
        let indexFromIndexAction = try NavigatorIndex(url: indexURL)
        XCTAssertEqual(indexFromIndexAction.count, 37)
        
        XCTAssertEqual(
            indexFromConvertAction.navigatorTree.root.dumpTree(),
            indexFromIndexAction.navigatorTree.root.dumpTree()
        )
    }
    
    func testObjectiveCNavigatorIndexGeneration() throws {
        let bundle = Folder(name: "unit-test-objc.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: objectiveCSymbolGraphFile),
        ])
        
        // The navigator index needs to test with the real File Manager
        let testTemporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(#function)-\(UUID())"
        )
        try FileManager.default.createDirectory(
            at: testTemporaryDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        defer {
            try? FileManager.default.removeItem(at: testTemporaryDirectory)
        }
        
        let bundleDirectory = testTemporaryDirectory.appendingPathComponent(
            bundle.name,
            isDirectory: true
        )
        try bundle.write(to: bundleDirectory)
        
        let targetDirectory = testTemporaryDirectory.appendingPathComponent(
            "output",
            isDirectory: true
        )
        
        var action = try ConvertAction(
            documentationBundleURL: bundleDirectory,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: false,
            currentPlatforms: nil,
            buildIndex: true
        )
        
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        _ = try action.perform(logHandle: .none)
        
        let index = try NavigatorIndex(url: targetDirectory.appendingPathComponent("index"))
        func assertAllChildrenAreObjectiveC(_ node: NavigatorTree.Node) {
            XCTAssertEqual(
                node.item.languageID,
                InterfaceLanguage.objc.mask,
                """
                Node from Objective-C symbol graph did not have Objective-C language ID: \
                '\(node.item.usrIdentifier ?? node.item.title)'"
                """
            )
            
            for childNode in node.children {
                assertAllChildrenAreObjectiveC(childNode)
            }
        }
        
        XCTAssertEqual(
            index.navigatorTree.root.children.count, 1,
            "The root of the navigator tree unexpectedly contained more than one child."
        )
        
        let firstChild = try XCTUnwrap(index.navigatorTree.root.children.first)
        assertAllChildrenAreObjectiveC(firstChild)
    }
    
    func testMixedLanguageNavigatorIndexGeneration() throws {
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        // The navigator index needs to test with the real File Manager
        let temporaryTestOutputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(#function)-\(UUID())"
        )
        try FileManager.default.createDirectory(
            at: temporaryTestOutputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        defer {
            try? FileManager.default.removeItem(at: temporaryTestOutputDirectory)
        }
        
        let bundleDirectory = try XCTUnwrap(
            Bundle.module.url(
                forResource: "MixedLanguageFramework",
                withExtension: "docc",
                subdirectory: "Test Bundles"
            ),
            "Unexpectedly failed to find 'MixedLanguageFramework.docc' test bundle."
        )
        
        var action = try ConvertAction(
            documentationBundleURL: bundleDirectory,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: temporaryTestOutputDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: false,
            currentPlatforms: nil,
            buildIndex: true
        )
        
        _ = try action.perform(logHandle: .none)
        
        let index = try NavigatorIndex(
            url: temporaryTestOutputDirectory.appendingPathComponent("index")
        )
        
        func assertForAllChildren(
            _ node: NavigatorTree.Node,
            assert: (_ node: NavigatorTree.Node) -> ()
        ) {
            assert(node)
            
            for childNode in node.children {
                assertForAllChildren(childNode, assert: assert)
            }
        }
        
        XCTAssertEqual(
            index.navigatorTree.root.children.count, 2,
            "The root of the navigator tree should contain '2' children, one for each language"
        )
        
        let swiftRootNode = try XCTUnwrap(
            index.navigatorTree.root.children.first { node in
                return node.item.languageID == InterfaceLanguage.swift.mask
            },
            "The navigator tree should contain a Swift item at the root."
        )
        
        let objectiveCRootNode = try XCTUnwrap(
            index.navigatorTree.root.children.first { node in
                return node.item.languageID == InterfaceLanguage.objc.mask
            },
            "The navigator tree should contain an Objective-C item at the root."
        )
        
        var swiftNavigatorEntries = [String]()
        assertForAllChildren(swiftRootNode) { node in
            XCTAssertEqual(
                node.item.languageID,
                InterfaceLanguage.swift.mask,
                """
                Node from Swift root node did not have Swift language ID: \
                '\(node.item.usrIdentifier ?? node.item.title)'"
                """
            )
            
            swiftNavigatorEntries.append(node.item.title)
        }
        
        let expectedSwiftNavigatorEntires = [
            "Swift",
            "MixedLanguageFramework",
            "Classes",
            "Bar",
            "Type Methods",
            "class func myStringFunction(String) throws -> String",
            "Structures",
            "Foo",
            "Initializers",
            "init(rawValue: UInt)",
            "Type Properties",
            "static var first: Foo",
            "static var fourth: Foo",
            "static var second: Foo",
            "static var third: Foo",
            "SwiftOnlyStruct",
            "Instance Methods",
            "func tada()",
        ]
        
        XCTAssertEqual(
            swiftNavigatorEntries,
            expectedSwiftNavigatorEntires,
            "Swift navigator contained unexpected content."
        )
        
        var objectiveCNavigatorEntries = [String]()
        assertForAllChildren(objectiveCRootNode) { node in
            XCTAssertEqual(
                node.item.languageID,
                InterfaceLanguage.objc.mask,
                """
                Node from Objective-C symbol graph did not have Objective-C language ID: \
                '\(node.item.usrIdentifier ?? node.item.title)'"
                """
            )
            
            objectiveCNavigatorEntries.append(node.item.title)
        }
        
        let expectedObjectiveNavigatorEntries = [
            "Objective-C",
            "MixedLanguageFramework",
            "Classes",
            "Bar",
            "Type Methods",
            "class func myStringFunction(String) throws -> String",
            "Variables",
            "_MixedLanguageFrameworkVersionNumber",
            "_MixedLanguageFrameworkVersionString",
            "Type Aliases",
            "Foo",
            "Enumerations",
            "Foo",
            "Enumeration Cases",
            "static var first: Foo",
            "static var fourth: Foo",
            "static var second: Foo",
            "static var third: Foo",
        ]
        
        XCTAssertEqual(
            objectiveCNavigatorEntries,
            expectedObjectiveNavigatorEntries,
            "Swift navigator contained unexpected content."
        )
    }
    
    func testDiagnosticLevel() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            TextFile(name: "Article.md", utf8Content: """
            Bad title

            This article has a malformed title and can't be analyzed, so it
            produces one warning.
            """),
            incompleteSymbolGraphFile,
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        let engine = DiagnosticEngine()
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            diagnosticLevel: "error",
            diagnosticEngine: engine
        )
        let result = try action.perform(logHandle: .none)

        XCTAssertEqual(engine.problems.count, 1, "\(ConvertAction.self) didn't filter out diagnostics above the 'error' level.")
        XCTAssert(result.didEncounterError)
    }

    func testDiagnosticLevelIgnoredWhenAnalyzeIsPresent() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            TextFile(name: "Article.md", utf8Content: """
            Bad title

            This article has a malformed title and can't be analyzed, so it
            produces one warning.
            """),
            incompleteSymbolGraphFile,
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        let engine = DiagnosticEngine()
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: true,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            diagnosticLevel: "error",
            diagnosticEngine: engine
        )
        let result = try action.perform(logHandle: .none)

        XCTAssertEqual(engine.problems.count, 2, "\(ConvertAction.self) shouldn't filter out diagnostics when the '--analyze' flag is passed")
        XCTAssertEqual(engine.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.Article.Title.NotFound", "org.swift.docc.SymbolNodeNotFound"])
        XCTAssert(result.didEncounterError)
        XCTAssert(engine.problems.contains(where: { $0.diagnostic.severity == .warning }))
    }

    func testDoesNotIncludeDiagnosticsInThrownError() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            TextFile(name: "Article.md", utf8Content: """
            Bad title

            This article has a malformed title and can't be analyzed, so it
            produces one warning.
            """),
            incompleteSymbolGraphFile,
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: true,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            diagnosticLevel: "error"
        )
        XCTAssertThrowsError(try action.performAndHandleResult()) { error in
            XCTAssert(error is ErrorsEncountered, "Unexpected error type thrown by \(ConvertAction.self)")
        }
    }

    // Verifies setting convert inherit docs flag
    func testConvertInheritDocsOption() throws {
        // Empty documentation bundle
        let bundle = Folder(name: "unit-test.documentation", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        // Verify setting the flag explicitly
        for flag in [false, true] {
            let action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                inheritDocs: flag)
            XCTAssertEqual(action.context.externalMetadata.inheritDocs, flag)
        }
        
        // Verify implicit value
        let action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider)
        XCTAssertEqual(action.context.externalMetadata.inheritDocs, false)
    }
    
    func testEmitsDigest() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            incompleteSymbolGraphFile,
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath).appendingPathComponent("target", isDirectory: true)

        let digestFileURL = targetDirectory
            .appendingPathComponent("diagnostics.json")
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider
        )
        
        XCTAssertThrowsError(try action.performAndHandleResult(), "The test bundle should have thrown an error about an incomplete symbol graph file")
        XCTAssert(testDataProvider.fileExists(atPath: digestFileURL.path), "The digest file should have been written even though compilation errors occurred")
        
        let data = try testDataProvider.contentsOfURL(digestFileURL)
        let diagnostics = try RenderJSONDecoder.makeDecoder().decode([Digest.Diagnostic].self, from: data)
        XCTAssertEqual(diagnostics.count, 1)

    }
    
    func testObjectiveCFeatureFlag() throws {
        let bundle = Folder(name: "unit-test-objc.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: objectiveCSymbolGraphFile),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath).appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider
        )
        
        try action.performAndHandleResult()
        XCTAssertFalse(
            testDataProvider.fileExists(atPath: targetDirectory.appendingPathComponent(NodeURLGenerator.Path.dataFolderName).path)
        )
        
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        try action.performAndHandleResult()
        XCTAssertTrue(
            testDataProvider.fileExists(atPath: targetDirectory.appendingPathComponent(NodeURLGenerator.Path.dataFolderName).path)
        )
    }
    
    /// Verifies that a metadata.json file is created in the output folder with additional metadata.
    func testCreatesBuildMetadataFileForBundleWithInfoPlistValues() throws {
        let bundle = Folder(
            name: "unit-test.docc",
            content: [InfoPlist(displayName: "TestBundle", identifier: "com.test.example")]
        )
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider
        )
        let result = try action.perform(logHandle: .standardOutput)
        
        let expectedOutput = Folder(name: ".docc-build", content: [
            JSONFile(
                name: "metadata.json",
                content: BuildMetadata(bundleDisplayName: "TestBundle", bundleIdentifier: "com.test.example")
            ),
        ])
        
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }

    func testConvertWithCustomTemplates() throws {
        let info = InfoPlist(displayName: "TestConvertWithCustomTemplates", identifier: "com.test.example")
        let index = TextFile(name: "index.html", utf8Content: """
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <title>Test</title>
            </head>
            <body data-color-scheme="auto"><p>hello</p></body>
        </html>
        """)
        let template = Folder(name: "template", content: [index])
        let header = TextFile(name: "header.html", utf8Content: """
        <style>
            header { background-color: rebeccapurple; }
        </style>
        <header>custom header</header>
        """)
        let footer = TextFile(name: "footer.html", utf8Content: """
        <style>
            footer { background-color: #fff; }
        </style>
        <footer>custom footer</footer>
        """)
        let bundle = Folder(name: "TestConvertWithCustomTemplates.docc", content: [
            info,
            header,
            footer,
        ])

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let targetURL = tempURL.appendingPathComponent("target", isDirectory: true)

        let bundleURL = try bundle.write(inside: tempURL)
        let templateURL = try template.write(inside: tempURL)

        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)

        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: dataProvider,
            fileManager: FileManager.default,
            experimentalEnableCustomTemplates: true
        )
        let result = try action.perform(logHandle: .standardOutput)

        // The custom template contents should be wrapped in <template> tags and
        // prepended to the <body>
        let expectedIndex = TextFile(name: "index.html", utf8Content: """
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <title>Test</title>
            </head>
            <body data-color-scheme="auto"><template id="custom-footer">\(footer.utf8Content)</template><template id="custom-header">\(header.utf8Content)</template><p>hello</p></body>
        </html>
        """)
        let expectedOutput = Folder(name: ".docc-build", content: [expectedIndex])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: FileManager.default)
    }
    
    private func uniformlyPrintDiagnosticMessages(_ problems: [Problem]) -> String {
        return problems.sorted(by: { (lhs, rhs) -> Bool in
            guard lhs.diagnostic.identifier != rhs.diagnostic.identifier else {
                return lhs.diagnostic.localizedSummary < rhs.diagnostic.localizedSummary
            }
            return lhs.diagnostic.identifier < rhs.diagnostic.identifier
        }) .map { $0.diagnostic.localizedDescription }.sorted().joined(separator: "\n")
    }
    
    #endif
}

private extension LinkDestinationSummary {
    // A convenience initializer for test data.
    init(
        kind: DocumentationNode.Kind,
        path: String,
        referenceURL: URL,
        title: String,
        language: SourceLanguage,
        abstract: String?,
        taskGroups: [TaskGroup],
        usr: String? = nil,
        availableLanguages: Set<SourceLanguage>,
        platforms: [PlatformAvailability]?,
        redirects: [URL]?
    ) {
        self.init(
            kind: kind,
            language: language,
            path: path,
            referenceURL: referenceURL,
            title: title,
            abstract: abstract.map { [.text($0)] },
            availableLanguages: availableLanguages,
            platforms: platforms,
            taskGroups: taskGroups,
            usr: usr,
            declarationFragments: nil,
            redirects: redirects,
            variants: []
        )
    }
}

private extension ImageReference {
    // A convenience initializer for test data.
    init(name: String, altText: String?, userInterfaceStyle: UserInterfaceStyle, displayScale: DisplayScale) {
        var asset = DataAsset()
        asset.register(
            URL(string: "/images/\(name)")!,
            with: DataTraitCollection(userInterfaceStyle: userInterfaceStyle, displayScale: displayScale)
        )
        self.init(
            identifier: RenderReferenceIdentifier(name),
            altText: altText,
            imageAsset: asset
        )
    }
}

extension File {
    /// A URL of the file node if it was located in the root of the file system.
    var absoluteURL: URL { return URL(string: "/\(name)")! }
}

extension Folder {
    /// Recreates a disk-based directory as a `Folder`.
    static func createFromDisk(url: URL) throws -> Folder {
        var content = [File]()
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
            for case let fileURL as URL in enumerator {
                if FileManager.default.fileExists(atPath: fileURL.path), fileURL.hasDirectoryPath {
                    content.append(try createFromDisk(url: fileURL))
                } else {
                    if fileURL.lastPathComponent == "Info.plist",
                       let infoPlistData = FileManager.default.contents(atPath: fileURL.path),
                       let infoPlist = try? PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any],
                       let displayName = infoPlist[InfoPlist.Content.CodingKeys.displayName.rawValue] as? String,
                       let identifier = infoPlist[InfoPlist.Content.CodingKeys.identifier.rawValue] as? String {
                        content.append(InfoPlist(displayName: displayName, identifier: identifier))
                    } else {
                        content.append(CopyOfFile(original: fileURL, newName: fileURL.lastPathComponent))
                    }
                }
            }
        }
        return Folder(name: url.lastPathComponent, content: content)
    }
}
