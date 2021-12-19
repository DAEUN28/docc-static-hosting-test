/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
 This class provides a simple way to transform a `FileSystemProvider` into a `RenderNodeProvider` to feed an index builder.
 The data from the disk is fetched and processed in an efficient way to build a navigator index.
 */
public class FileSystemRenderNodeProvider: RenderNodeProvider {
    
    /// The internal `FileSystemProvider` reference.
    private let dataProvider: FileSystemProvider
    
    /// The list of problems the provider encountered during the process.
    private var problems = [Problem]()
    
    /// The enqueued file system nodes.
    private var queue = [FSNode]()
    
    /**
     Initialize an instance to provide `RenderNode` instances from a give `FileSystemProvider`.
     */
    public init(fileSystemProvider: FileSystemProvider) {
        dataProvider = fileSystemProvider
        
        // Insert the first node in the queue
        queue.append(fileSystemProvider.fileSystem)
    }
    
    /// Returns a render node that can be processed by an index creator, for example.
    public func getRenderNode() -> RenderNode? {
        var renderNode: RenderNode? = nil
        
        while let next = queue.first, renderNode == nil {
            switch next {
            case .directory(let dir):
                queue.append(contentsOf: dir.children)
            case .file(let file):
                // we need to process JSON files only
                if file.url.pathExtension.lowercased() == "json" {
                    do {
                        let data = try Data(contentsOf: file.url)
                        renderNode = try RenderNode.decode(fromJSON: data)
                    } catch {
                        let diagnostic = Diagnostic(source: file.url,
                                                         severity: .warning,
                                                         range: nil,
                                                         identifier: "org.swift.docc",
                                                         summary: "Invalid file found while indexing content: \(error.localizedDescription)")
                        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
                        problems.append(problem)
                    }
                }
            }
            queue.removeFirst()
        }
        
        return renderNode
    }
    
    /// Get the problems that happened during the process.
    /// - Returns: An array with the problems encountered during the filesystem read of render nodes.
    public func getProblems() -> [Problem] {
        return problems
    }
    
}

extension RenderNode {
    
    /// Returns a navigator title preferring the fragments inside the metadata, if applicable.
    func navigatorTitle() -> String? {
        let pageType = navigatorPageType()
        guard ![.framework, .class, .structure, .enumeration, .protocol, .typeAlias, .associatedType].contains(pageType) else { return metadata.title }
        guard let fragments = metadata.fragments else { return metadata.title }
        return fragments.map { token in
            return token.text
        }.joined()
    }
    
    /// Returns the NavigatorIndex.PageType indicating the type of the page.
    public func navigatorPageType() -> NavigatorIndex.PageType {
        
        // This is a workaround to support plist keys.
        if metadata.roleHeading?.lowercased() == "property list key" { return  .propertyListKey }
        else if metadata.roleHeading?.lowercased() == "property list key reference" { return  .propertyListKeyReference }
        
        switch self.kind {
        case .article:
            if let role = metadata.role {
                return NavigatorIndex.PageType(role: role)
            }
            return NavigatorIndex.PageType.article
        case .tutorial:
            return NavigatorIndex.PageType.tutorial
        case .section:
            return NavigatorIndex.PageType.section
        case .overview:
            return NavigatorIndex.PageType.overview
        case .symbol:
            if let symbolKind = metadata.symbolKind {
                return NavigatorIndex.PageType(symbolKind: symbolKind)
            }
            if let role = metadata.role {
                return NavigatorIndex.PageType(role: role)
            }
            return NavigatorIndex.PageType.symbol
        }
    }
    
}
