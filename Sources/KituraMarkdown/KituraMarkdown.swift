/**
 * Copyright IBM Corporation 2016, 2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation

import Ccmark
import KituraTemplateEngine

/**
 Rendering options for KituraMarkdown, allowing the generated HTML to be wrapped in a
 page template. The page template should contain
 `<snippetInsertLocation></snippetInsertLocation>`, which will be substituted with the
 generated HTML content.

 _Note: If you do not wish to customize the page template, `"default"` can be specified._

 ### Usage Example:

 ```swift
 let markdownOptions = MarkdownOptions(pageTemplate: "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"UTF-8\"></head><body><div><snippetInsertLocation></snippetInsertLocation></div></body></html>")

 router.add(templateEngine: KituraMarkdown())

 router.get("/docs") { _, response, next in
     try response.render("Example.md", context: [String:Any](), options: markdownOptions)
     response.status(.OK)
     next()
 }
 ```
*/
public struct MarkdownOptions: RenderingOptions {
    let pageTemplate: String

    /// Create a `MarkdownOptions` that specifies a custom HTML page template, into
    /// which the generated HTML content will be inserted.
    ///
    /// - Parameter pageTemplate: String form of page template.
    public init(pageTemplate: String) {
        self.pageTemplate = pageTemplate
    }
}

/**
 A Kitura [`TemplateEngine`](https://kitura-next.github.io/Kitura-TemplateEngine/Protocols/TemplateEngine.html)
 that enables a Kitura server to render HTML content generated from Markdown
 templates (`.md` files).

 This class also provides helper methods for converting Markdown formatted text
 from a `String` or `Data` to HTML.

 - Note: Under the covers this templating engine uses the [cmark](https://github.com/commonmark/cmark)
         C language reference implementation of Markdown.

 ### Usage Example:

 ```swift
 router.add(templateEngine: KituraMarkdown())

 router.get("/docs") { _, response, next in
     try response.render("Example.md", context: [String:Any]())
     response.status(.OK)
     next()
 }
 ```
*/
public class KituraMarkdown: TemplateEngine {
    /// The file extension of files that will be rendered by the KituraMarkdown
    /// template engine. By default, Kitura will search for these in the `./Views/`
    /// directory, which can be customized by setting the [`router.viewsPath`](https://kitura-next.github.io/Kitura/Classes/Router.html#/s:6Kitura6RouterC9viewsPathSSvp)
    /// property.
    public let fileExtension = "md"

    /// Create a `KituraMarkdown` instance that can be registered with a Kitura router.
    public init() {}

    // This function is needed to satisfy TemplateEngine protocol, it is not possible to
    // statisfy swift protocols by providing default arguments. Otherwise,
    // `render(:filePath:context:options)` with default options argument would be used.
    /// Take a template file in Markdown format and generate HTML format content to
    /// be sent back to the client.
    ///
    /// - Parameter filePath: The path of the template file in Markdown format to use
    ///                      when generating the content.
    /// - Parameter context: A set of variables in the form of a Dictionary of
    ///                     Key/Value pairs. **Note:** This parameter is ignored at
    ///                     this time.
    /// - Returns: A String containing an HTML representation of the text marked up
    ///            using Markdown.
    /// - Throws: An error if the template file cannot be read.
    public func render(filePath: String, context: [String: Any]) throws -> String {
        return try render(filePath: filePath, context: context, options: NullRenderingOptions())
    }
    
    // This function is needed to satisfy TemplateEngine protocol.
    /// Take a template file in Markdown format and generate HTML format content to
    /// be sent back to the client.
    ///
    /// _Note that rendering of context is not supported at this time, and the `with`
    /// and `forKey` parameters are currently ignored._
    ///
    /// - Parameter filePath: The path of the template file in Markdown format to use
    ///                      when generating the content.
    /// - Parameter with: A value that conforms to Encodable.
    ///             **Note:** This parameter is ignored at this time.
    /// - Parameter forKey:  A value used to match the Encodable values to the
    ///             correct variable in a template file.
    ///             **Note:** This parameter is ignored at this time.
    /// - Parameter options: A `RenderingOptions` used to customize the output. The
    ///                      HTML page template can be customized by providing an
    ///                      instance of `MarkdownOptions`.
    /// - Returns: A String containing an HTML representation of the text marked up
    ///            using Markdown.
    /// - Throws: An error if the template file cannot be read.
    public func render<T: Encodable>(filePath: String, with: T, forKey: String?, options: RenderingOptions, templateName: String) throws -> String {
        //Pass through empty context as it's never used
        return try render(filePath: filePath, context: [:], options: options)
    }

    /// Take a template file in Markdown format and generate HTML format content to
    /// be sent back to the client.
    ///
    /// _Note that rendering of context is not supported at this time, and the
    /// `context` parameter is currently ignored._
    ///
    /// - Parameter filePath: The path of the template file in Markdown format to use
    ///                      when generating the content.
    /// - Parameter context: A set of variables in the form of a Dictionary of
    ///                     Key/Value pairs. **Note:** This parameter is ignored at
    ///                     this time
    /// - Parameter options: A `RenderingOptions` used to customize the output. The
    ///                      HTML page template can be customized by providing an
    ///                      instance of `MarkdownOptions`.
    /// - Returns: A String containing an HTML representation of the text marked up
    ///            using Markdown.
    /// - Throws: An error if the template file cannot be read.
    public func render(filePath: String, context: [String: Any],
                       options: RenderingOptions) throws -> String {
        let md = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let snippet = KituraMarkdown.render(from: md)

        if let options = options as? MarkdownOptions, snippet != "" {
            return KituraMarkdown.createPage(from: snippet, withTemplate: options.pageTemplate)
        }

        return snippet
    }

    /// Generate HTML content from a Data struct containing text marked up in
    /// Markdown in the form of UTF-8 bytes.
    ///
    /// - Parameter from: The Data struct containing markdown text in UTF-8.
    /// - Returns: A String containing an HTML representation of the text marked up
    ///            using Markdown.
    public static func render(from: Data) -> String {
#if swift(>=5)
        return from.withUnsafeBytes() { (byteBuffer: UnsafeRawBufferPointer) -> String in
            let bytes = byteBuffer.bindMemory(to: Int8.self).baseAddress
            guard let htmlBytes = cmark_markdown_to_html(bytes, from.count, 0) else { return "" }
            let html = String(utf8String: htmlBytes)
            free(htmlBytes)
            return html ?? ""
        }
#else
        return from.withUnsafeBytes() { (bytes: UnsafePointer<Int8>) -> String in
            guard let htmlBytes = cmark_markdown_to_html(bytes, from.count, 0) else { return "" }
            let html = String(utf8String: htmlBytes)
            free(htmlBytes)
            return html ?? ""
        }
#endif
    }

    /// Generate HTML content from a String containing text marked up in Markdown.
    ///
    /// - Parameter from: The String containing markdown text in UTF-8.
    /// - Returns: A String containing an HTML representation of the text marked up
    ///            using Markdown.
    public static func render(from: String) -> String {
        guard let md = from.data(using: .utf8) else {
            return ""
        }

        return KituraMarkdown.render(from: md)
    }

    /// Generate an HTML page from a String containing text marked up in Markdown.
    ///
    /// - Parameter from: The String containing markdown in UTF-8.
    /// - Parameter pageTemplate: The HTML page template to use. The page template
    ///                           should contain `<snippetInsertLocation></snippetInsertLocation>`,
    ///                           which will be substituted with the generated HTML
    ///                           content.
    ///                           _Note: If you do not wish to customize the page
    ///                           template, `"default"` can be specified._
    /// - Returns: A String containing an HTML representation of the text marked up
    ///            using Markdown, enclosed in an HTML page corresponding to the
    ///            `pageTemplate` supplied.
    public static func render(from: String, pageTemplate: String) -> String {
        let snippet = KituraMarkdown.render(from: from)
        return KituraMarkdown.createPage(from: snippet, withTemplate: pageTemplate)
    }

    /// Wrap markdown
    private static func createPage(from: String, withTemplate: String) -> String {
        if(withTemplate == "default") {
            return "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"UTF-8\"></head><body>\(from)</body></html>"
        }

        let result = withTemplate.replacingOccurrences(of: "<snippetInsertLocation></snippetInsertLocation>", with: from)
        
        return (result == withTemplate ? from : result)
    }
}
